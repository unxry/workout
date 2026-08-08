/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: ["Outfit", "Geist", "system-ui", "sans-serif"],
        mono: ["JetBrains Mono", "SFMono-Regular", "monospace"],
      },
      colors: {
        coach: {
          ink: "#111114",
          panel: "#17171c",
          line: "rgba(255,255,255,0.1)",
          violet: "#8b7cf6",
          green: "#61d394",
          amber: "#e4bc58",
        },
      },
    },
  },
  plugins: [],
};

