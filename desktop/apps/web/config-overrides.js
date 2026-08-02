var path = require('path');
const { override, babelInclude, addWebpackPlugin, overrideDevServer } = require('customize-cra')
const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer');
const TerserPlugin = require("terser-webpack-plugin");

const addDevServerConfig = () => config => {
  return {
    ...config,
    client: {
      overlay: false
    }
  };
}

/** Yarn workspaces hoist react to desktop/node_modules; CRA ModuleScopePlugin blocks that. */
function allowWorkspaceNodeModules(config) {
  const ModuleScopePlugin = require('react-dev-utils/ModuleScopePlugin');
  config.resolve.plugins = (config.resolve.plugins || []).filter(
    (p) => !(p instanceof ModuleScopePlugin)
  );
  return config;
}

module.exports = {
  webpack: function (config, env) {
    if (process.env.NODE_ENV === 'production') {
      config.devtool = false;
    }
    if (env === 'production') {
      config.optimization = {
        minimize: true,
        minimizer: [new TerserPlugin()],
      };
    }

    // TipTap (ESM) + React 17: resolve jsx-runtime without extension / fullySpecified
    const rootNm = path.resolve(__dirname, '../../node_modules');
    config.resolve = config.resolve || {};
    config.resolve.alias = {
      ...(config.resolve.alias || {}),
      react: path.join(rootNm, 'react'),
      'react-dom': path.join(rootNm, 'react-dom'),
      'react/jsx-runtime': path.join(rootNm, 'react/jsx-runtime.js'),
      'react/jsx-dev-runtime': path.join(rootNm, 'react/jsx-dev-runtime.js'),
    };
    config.module = config.module || {};
    config.module.rules = config.module.rules || [];
    config.module.rules.push({
      test: /\.m?js$/,
      resolve: { fullySpecified: false },
    });

    allowWorkspaceNodeModules(config);

    const next = Object.assign(
      config,
      override(
        // 判断环境变量ANALYZER参数的值
        process.env.ANALYZER && addWebpackPlugin(new BundleAnalyzerPlugin()),
        babelInclude([
          /* transpile (converting to es5) code in src/ and shared component library */
          path.resolve('src'),
          path.resolve('../../packages'),
        ])
      )(config, env)
    );
    // override() may restore CRA plugins — strip ModuleScopePlugin last.
    return allowWorkspaceNodeModules(next);
  },
  devServer: overrideDevServer(addDevServerConfig())
}
