/// Central route path constants.
abstract class Routes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const otp = '/otp';
  static const scanIntro = '/scan-intro';
  static const scanCamera = '/scan-camera';
  static const scanResult = '/scan-result';
  static const scanManual = '/scan-manual';
  static const preferences = '/preferences';

  // Shell tabs
  static const home = '/home';
  static const explore = '/explore';
  static const tryonTab = '/tryon';
  static const wishlist = '/wishlist';
  static const profile = '/profile';

  // Pushed pages
  static const product = '/product'; // /product/:id
  static const tryon = '/try-on'; // /try-on/:id
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const orderSuccess = '/order-success';
  static const orders = '/orders';
  static const compare = '/compare';
  static const assistant = '/assistant';
  static const loyalty = '/loyalty';
  static const settings = '/settings';
  static const notifications = '/notifications';
  static const registerStore = '/register-store';
}
