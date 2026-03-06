import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        forest: {
          deep: '#1B3022',
          DEFAULT: '#1B3022',
        },
        sprout: {
          DEFAULT: '#4CAF50',
          light: '#81C784',
          dark: '#2D5A27',
        },
        mist: {
          DEFAULT: '#F4F7F5',
          sky: '#E0F2F1',
        },
        'dark-bg': '#0F1A14',
        'cloud-dark': '#1E2A3A',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
      backgroundImage: {
        'gradient-radial': 'radial-gradient(var(--tw-gradient-stops))',
        'hero-gradient': 'linear-gradient(135deg, #1B3022 0%, #2D5A27 50%, #1B3022 100%)',
      },
    },
  },
  plugins: [],
  darkMode: 'class',
}

export default config
