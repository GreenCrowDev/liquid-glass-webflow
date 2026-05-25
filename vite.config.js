import { defineConfig } from 'vite'

export default defineConfig({
	server: {
		host: 'localhost', // Ensures you can access it on your local network
		port: 3000,
		cors: true, // Allows cross-origin requests (useful when embedding on other sites)
		hmr: {
			host: 'localhost',
			protocol: 'ws',
		},
	},
	build: {
		minify: true, // Minifies the output for better performance
		manifest: true,
		rollupOptions: {
			input: './src/main.js', // Your main entry file
			output: {
				format: 'umd', // UMD format maximizes compatibility when loaded via a <script> tag
				entryFileNames: 'main.js', // Force the output filename to be 'main.js'
				esModule: false, // Avoids adding ES module markers since we’re using UMD
				compact: true, // Produces a compact, minimized output bundle
			},
		},
	},
})
