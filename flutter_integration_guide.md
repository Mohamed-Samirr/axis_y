# Axis Y — Flutter Developer Integration Guide

Welcome to the Axis Y project! This document serves as your complete guide to integrating the Flutter application with the Axis Y AI backend. It covers architecture, responsibilities, API contracts, state management, and implementation guidelines.

Please read this document carefully before writing any integration code.

---

## 1. Project Overview

**What this application does:**  
Axis Y is a next-generation virtual fitting room and body scanning platform. It allows users to capture photos of their body to extract accurate physical measurements. These measurements are then used to generate a customized 3D body avatar, provide highly accurate size recommendations, and perform a fully 3D virtual garment try-on.

**The User Journey:**  
1. **Onboarding:** User opens the app and is assigned an anonymous session (`device_id`).
2. **Body Scan:** User takes two photos (front and side profile) following strict camera guides.
3. **Measurement & Mesh:** The backend processes the photos, returns accurate body measurements (chest, waist, inseam, etc.), and generates a base 3D body mesh.
4. **Catalog Browsing:** User browses available garments.
5. **Virtual Try-On:** User selects a garment. The app renders a 3D view of the user's body wearing the requested garment.
6. **Fit Analysis:** The app displays a detailed fit verdict (e.g., "Perfect Fit", "Too Tight") and recommends the best size.

**Current Development Stage:**  
Alpha/Prototype. The core Try-On API runs on FastAPI, while the image-to-measurement pipeline runs on a separate Body Scan REST API.

**MVP Scope:**  
The Flutter MVP will focus on smooth camera capture, uploading photos to the Body Scan API, displaying the 3D viewer (GLB format), rendering the product catalog, toggling between different t-shirt sizes in 3D, and gracefully handling the Try-On API flows.

---

## 2. High-Level System Architecture

The architecture relies on a clear separation of concerns. Flutter acts strictly as a presentation and capture layer.

```mermaid
flowchart TD
    subgraph Client
        F[Flutter App]
    end

    subgraph API Layer
        API[FastAPI Gateway]
    end

    subgraph Backend Engines
        BSE[Body Scan Engine\n(MediaPipe / Rembg)]
        FE[Fit Engine]
        ME[Morph Engine]
        TE[Texture Engine]
    end

    subgraph Data & Storage
        DB[(PostgreSQL)]
        Redis[(Redis Cache)]
        S3[CDN / Object Storage\n(GLB Files)]
    end

    F -->|REST / JSON| API
    F -->|Download GLB| S3
    
    API --> BSE
    API --> FE
    API --> ME
    API --> TE
    
    API --> DB
    API --> Redis
    
    ME --> S3
    TE --> S3
    BSE --> S3
```

---

## 3. Flutter Responsibilities

As the Flutter application, your responsibilities include:

*   **Authentication & Session:** Generating and securely storing a persistent UUID (`device_id`) for anonymous users.
*   **Camera Capture:** Providing a highly guided camera UI with overlays for front and side profile shots.
*   **Image Optimization:** Compressing and resizing images before upload to save bandwidth (once the upload API is exposed).
*   **3D Viewer:** Rendering `.glb` files for both the body model and the morphed garments. Supporting gestures (rotate, zoom).
*   **State & Caching:** Caching product catalogs, measurements, and downloaded `.glb` files locally to minimize network usage.
*   **UI/UX:** Handling complex loading states (Try-On can take ~600ms+), skeleton loaders, and intuitive error messaging.
*   **Routing:** Managing the user journey from scanning to catalog to try-on.

---

## 4. Backend Responsibilities

**CRITICAL RULE:** The Flutter application must **NEVER** implement the following logic. These are strictly backend responsibilities to ensure intellectual property protection and cross-platform consistency.

*   **Measurement Extraction:** Do not attempt to use MediaPipe or calculate circumferences in Dart. The backend AI handles all segmentation and Ramanujan ellipse calculations.
*   **Mesh Generation (GLB):** Do not generate or modify 3D vertices/meshes on the client.
*   **Size Recommendation:** Do not write logic to compare body measurements against garment size charts. The backend `FitEngine` handles ease thresholds and verdicts.
*   **Fit Analysis:** Do not determine if a garment is "Too Tight" or "Perfect Fit". Rely entirely on the API's `fit_result` object.
*   **Garment Morphing:** The complex deformation of clothing to match the user's body is exclusively a backend task.

---

## 5. Complete User Flow

### 1. Splash & Init
*   **Purpose:** App initialization.
*   **Backend Calls:** None. (Generate `device_id` if missing).
*   **Navigation:** To `Home` (if scan exists) or `Scan Body`.

### 2. Scan Body (Camera)
*   **Purpose:** Capture front and side profiles.
*   **Inputs:** Camera feed, device orientation sensors.
*   **Outputs:** Two optimized images (JPEG/WebP) and user height input.
*   **Navigation:** To `Processing`.

### 3. Processing & Scan Result
*   **Purpose:** Wait for AI to extract measurements and generate the 3D body.
*   **Backend Calls:** `POST /scan` (JSON) or `POST /scan-3d` (GLB) to the Body Scan API.
*   **Outputs:** Displays extracted measurements and confidence score. Caches the 3D body model.
*   **Navigation:** To `Home` / Catalog.

### 4. Home (Product Catalog)
*   **Purpose:** Browse garments.
*   **Backend Calls:** `GET /api/v1/products`
*   **Navigation:** Tap product -> `Product Details`.

### 5. Product Details & Fit Check
*   **Purpose:** View garment details and instant size recommendation.
*   **Backend Calls:** `POST /api/v1/fit-check` (Lightweight, no GLB generated).
*   **Outputs:** Displays recommended size and region-specific fit analysis.
*   **Navigation:** Tap "Try On" -> `Try-On 3D Viewer`.

### 6. Try-On (3D Viewer & Size Toggling)
*   **Purpose:** Full 3D visualization of the garment on the user's body.
*   **Backend Calls:** `POST /api/v1/try-on` (Call this when toggling between sizes).
*   **Outputs:** Renders the 3D body wearing the selected garment. 
*   **Size Toggling Feature:** The UI must provide a size selector (S, M, L, XL). When the user taps a different size, the app calls `POST /api/v1/try-on` for that specific size variant and smoothly transitions the 3D viewer to show the new fit.
*   **Navigation:** Back to `Product Details` or to `Checkout`.

---

## 6. API Documentation

**Base URL:** `https://api.axisy.app/api/v1`

### `POST /scan` & `POST /scan-3d` (Body Scan API)
*   **Purpose:** Extract measurements and generate 3D body avatar directly from photos.
*   **Content-Type:** `multipart/form-data`
*   **Request:** `front_image` (File), `side_image` (File), `height_cm` (Number).
*   **Response (`/scan`):** JSON with measurements and confidence score.
*   **Response (`/scan-3d`):** Binary `.glb` model (`model/gltf-binary`).

### `POST /body-scan` (Main API)
*   **Purpose:** Register the completed scan in the main database to get a `scan_id`.
*   **Request:** `device_id`, `measurements` object (from `/scan`), `confidence`.
*   **Response (201):** Returns `scan_id` (UUID).

### `POST /fit-check`
*   **Purpose:** Fast size recommendation without 3D processing.
*   **Request:** `scan_id`, `product_id`, `size_label`.
*   **Response (200):** Returns `fit_result` object.

### `POST /try-on`
*   **Purpose:** Full virtual try-on and GLB generation.
*   **Request:** `scan_id`, `product_variant_id`, `auto_select_size` (boolean).
*   **Response (200):** Returns `tryon_id`, `garment_glb_url`, `body_glb_url`, and `fit_result`.

### `GET /products`
*   **Purpose:** Fetch catalog.
*   **Query Params:** `store_id`, `category`, `gender`, `page`, `page_size`.
*   **Response (200):** Paginated list of products.

---

## 7. JSON Models

### Body Scan Measurement Object
```json
{
  "device_id": "android-uuid-xxx",
  "measurements": {
    "height_cm": 180.0,
    "shoulder_cm": 42.6,
    "chest_cm": 99.5,
    "waist_cm": 85.3,
    "hips_cm": 92.4,
    "inseam_cm": 81.3,
    "weight_kg_estimate": 78.0
  },
  "confidence": 0.93
}
```

### Fit Result Object
```json
{
  "overall_verdict": "PERFECT_FIT",
  "overall_confidence": 0.93,
  "regions": {
    "chest_cm": {
      "body_cm": 99.5,
      "garment_cm": 104.0,
      "ease_cm": 4.5,
      "verdict": "PERFECT_FIT",
      "explanation": "Chest has a comfortable 4.5cm of room.",
      "constrained": false
    }
  },
  "recommendation": "Size M is a great fit for your body measurements.",
  "alternative_sizes": [
    { "size_label": "L", "predicted_verdict": "LOOSE_FIT" }
  ],
  "has_constraint_warnings": false
}
```

*Verdicts Enum:* `NOT_RECOMMENDED`, `TOO_TIGHT`, `SLIM_FIT`, `PERFECT_FIT`, `LOOSE_FIT`, `TOO_LOOSE`.

---

## 8. State Management

**Recommendation:** Riverpod (or BLoC if preferred by the team).

*   **Providers:** 
    *   `SessionProvider`: Manages `device_id` and active `scan_id`.
    *   `CatalogProvider`: Fetches and caches product lists.
    *   `TryOnProvider`: Manages the async state of `POST /try-on` (Loading -> Success with GLB URLs -> Error).
*   **Caching:** Essential. Once a Try-On is generated, cache the GLB URLs mapped to the `product_variant_id`. The backend also caches this via Redis, but client-side caching saves a network call.
*   **Offline Behavior:** The app requires internet for Body Scanning and Try-On. Product catalogs can be cached offline, but transactions require connectivity.

---

## 9. Networking Layer

Use **Dio** for robust networking.

*   **Interceptors:** Inject `device_id` into headers or request bodies globally.
*   **Timeouts:** 
    *   Standard requests (Products, Fit Check): 10 seconds.
    *   Try-On API: The morph process takes ~300-600ms, but network transfer of GLBs adds time. Set timeout to **30 seconds**.
    *   Body Scan (Future Image Upload): Set timeout to **60 seconds**.
*   **Retries:** Implement exponential backoff for 5xx errors. Do NOT retry 422 (Validation/Low Confidence) errors.

---

## 10. Camera Requirements

To ensure the AI backend provides accurate measurements, the Flutter camera UI must enforce:
*   **Overlays:** Display a silhouette guide. The user's head, shoulders, and feet must align with the guide.
*   **Aspect Ratio:** Standard 4:3 or 16:9 vertical.
*   **Resolution:** Minimum 1080p height.
*   **Format:** Compress to high-quality JPEG (80-90% quality) or WebP.
*   **Validation:** Use device sensors (gyroscope) to ensure the phone is held perfectly vertical (0° pitch/roll) before allowing capture.

---

## 11. 3D Viewer Integration

Use a package like `model_viewer_plus` (based on Google's `<model-viewer>`).

*   **Loading:** The API returns two URLs: `body_glb_url` and `garment_glb_url`. You must overlay these. (Depending on the package, you may need a viewer that supports multiple meshes, or the backend may need to merge them. *Confirm with backend team if they plan to merge, or if you should load the garment over a local generic body mesh*).
*   **Memory:** GLB files can be 1MB - 5MB. Dispose of the 3D viewer widget resources completely when navigating away to prevent OOM (Out of Memory) crashes on low-end Androids.

---

## 12. Error Handling

Map backend HTTP status codes to user-friendly UI:

*   **404 Not Found:** (e.g., Scan ID missing). Kick user back to Splash/Onboarding.
*   **422 Unprocessable Entity:** Usually means Body Scan confidence is too low (< 60%). 
    *   **UI Action:** Show a modal: *"We couldn't measure you accurately. Please wear tighter clothing, ensure good lighting, and try again."*
*   **500 Internal Server Error:** Morph failure or Storage error.
    *   **UI Action:** Show a polite failure state. Offer a "Retry" button.

---

## 13. Performance Guidelines

*   **Lazy Loading:** Paginate the `GET /products` endpoint using a ScrollController.
*   **Image Caching:** Use `cached_network_image` for product thumbnails.
*   **GLB Caching:** Use `flutter_cache_manager` to download and store `.glb` files locally so repeat viewings of the same try-on are instant.

---

## 14. Security

*   **HTTPS:** Enforce secure connections.
*   **Secure Storage:** Store the `device_id` and active `scan_id` using `flutter_secure_storage`.
*   **Image Privacy:** Photos taken by the camera should be written to temporary directories (`getTemporaryDirectory()`) and deleted immediately after successful upload. Do NOT save them to the user's public camera roll.

---

## 15. Repository Structure

A standard feature-first architecture is recommended:

```text
lib/
├── core/
│   ├── network/       # Dio client, interceptors
│   ├── theme/         # Colors, typography
│   └── errors/        # Exception classes
├── features/
│   ├── onboarding/
│   ├── body_scan/     # Camera UI, measurement display
│   ├── catalog/       # Product list, details
│   └── try_on/        # 3D Viewer, fit analysis
├── models/            # Freezed/JsonSerializable classes
├── services/          # Secure storage, GLB caching
└── main.dart
```

---

## 16. Integration Checklist

*   [ ] Implement secure `device_id` generation and storage.
*   [ ] Build guided Camera UI (Front & Side profiles) with pitch/roll validation.
*   [ ] Implement multipart image upload for `POST /scan` and `POST /scan-3d`.
*   [ ] Handle 422 Low Confidence scan errors gracefully.
*   [ ] Parse and display measurements from the `/scan` response, then register them with `/body-scan`.
*   [ ] Implement Product Catalog list and details views.
*   [ ] Implement `POST /fit-check` for instant size recommendations on product pages.
*   [ ] Implement `POST /try-on` and handle long loading states.
*   [ ] **Implement Try-On Size Toggling:** Add a UI to let users switch sizes (S, M, L) and reload the 3D model for each.
*   [ ] Integrate 3D Viewer to display downloaded `.glb` files.
*   [ ] Implement local caching for GLB files to save bandwidth.

---

## 17. Known Limitations

*   **Try-On Processing:** While the morph engine is fast (~300ms), downloading a 2MB GLB on a 3G network will take time. Always use skeleton loaders or engaging animations during this wait.

---

## 18. Handoff Notes (To the Flutter Dev)

Hey! Welcome to the frontend side of Axis Y. 

To get up to speed quickly, start by reviewing the `docs/api_reference.md` in the backend repo (it matches Section 6 of this document). 

**Important Assumptions:**
You will be communicating with a unified backend server. The Body Scan endpoints handle the heavy AI image processing (`POST /scan-3d`), returning a raw GLB file and measurements. You then pass those measurements to the main session registration (`POST /body-scan`) before doing the Virtual Try-On.

**Size Toggling:**
Make sure the 3D viewer screen includes a size selector at the bottom! The user should see the recommended size first, but they can tap "S", "M", "L", etc., to see how a tight vs loose t-shirt actually looks on their body mesh in 3D.

If you hit any issues with the 3D Viewer not looking right (e.g. garments clipping into the body), that is a Backend Morph Engine issue, not a Flutter issue. Ping the AI team!

Good luck building this!
