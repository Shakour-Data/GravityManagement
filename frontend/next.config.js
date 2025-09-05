/** @type {import('next').NextConfig} */
const nextConfig = {
  // Bundle optimization
  swcMinify: true,

  // Compression
  compress: true,

  // CDN configuration
  assetPrefix: process.env.NODE_ENV === 'production' ? 'https://cdn.gravitypm.com' : '',

  // Image optimization
  images: {
    domains: ['localhost', 'cdn.gravitypm.com'],
    formats: ['image/webp', 'image/avif'],
    minimumCacheTTL: 60,
  },

  // Webpack optimization
  webpack: (config, { dev, isServer }) => {
    // Bundle analyzer (only in development)
    if (dev && !isServer) {
      const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer')
      if (process.env.ANALYZE === 'true') {
        config.plugins.push(
          new BundleAnalyzerPlugin({
            analyzerMode: 'server',
            openAnalyzer: true,
          })
        )
      }
    }

    // Optimize chunks
    if (!dev && !isServer) {
      config.optimization.splitChunks.chunks = 'all'
      config.optimization.splitChunks.cacheGroups = {
        vendor: {
          test: /[\\/]node_modules[\\/]/,
          name: 'vendors',
          chunks: 'all',
        },
        common: {
          name: 'common',
          minChunks: 2,
          chunks: 'all',
        },
        // Route-based code splitting
        pages: {
          test: /[\\/]pages[\\/]/,
          name: 'pages',
          chunks: 'all',
        },
        components: {
          test: /[\\/]components[\\/]/,
          name: 'components',
          chunks: 'all',
        },
      }
    }

    return config
  },

  // Headers for performance
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'X-Frame-Options',
            value: 'DENY',
          },
          {
            key: 'X-XSS-Protection',
            value: '1; mode=block',
          },
        ],
      },
      {
        source: '/static/(.*)',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=31536000, immutable',
          },
        ],
      },
    ]
  },
}

module.exports = nextConfig
