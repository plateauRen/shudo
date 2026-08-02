const { createProxyMiddleware } = require("http-proxy-middleware");

/**
 * Same-origin proxy so browser calls /v1/shudo without CORS.
 * Target: shudo-org on :8092
 */
module.exports = function (app) {
  const target = process.env.SHUDO_ORG_PROXY || "http://127.0.0.1:8092";
  app.use(
    "/v1/shudo",
    createProxyMiddleware({
      target,
      changeOrigin: true,
    })
  );
};
