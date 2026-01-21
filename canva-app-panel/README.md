# Digital Vision Board - Marketing Site

This is a static marketing website that showcases the features and capabilities of the Digital Vision Board mobile application. The site is built with React, TypeScript, and Vite, and provides information about the app's features, board types, and privacy policy.

## Features

- **Single-Page Design**: Smooth scrolling navigation through all sections
- **Responsive Layout**: Optimized for mobile, tablet, and desktop viewing
- **Modern UI/UX**: Material Design 3 inspired with deep purple theme matching the app
- **Comprehensive Privacy Policy**: Detailed information about data collection and user rights
- **Feature Showcase**: Visual presentation of all app capabilities

## Sections

1. **Hero Section**: Eye-catching introduction with call-to-action
2. **Features Overview**: Grid of 9 main features with descriptions
3. **Board Types**: Detailed showcase of 4 board types (Freeform, Goal Canvas, Physical Board, Grid Board)
4. **Privacy Policy**: Comprehensive privacy information covering:
   - Data collection practices
   - Optional data (location, music integration)
   - Authentication methods
   - Local-first storage
   - Permissions requested
   - User rights

## Development

### Prerequisites

- Node.js >= 18
- npm or yarn

### Setup

```bash
cd canva-app-panel
npm install
```

### Development Server

```bash
npm run dev
```

The site will be available at `http://localhost:5173`

### Build

```bash
npm run build
```

This will create a `dist/` directory with static files ready for deployment.

### Preview Build

```bash
npm run preview
```

Preview the production build locally before deployment.

## Deployment

The build output in the `dist/` directory contains static HTML, CSS, and JavaScript files that can be deployed to any static hosting service:

- **Vercel**: Connect your repository and deploy automatically
- **Netlify**: Drag and drop the `dist/` folder or connect via Git
- **GitHub Pages**: Deploy the `dist/` folder to GitHub Pages
- **AWS S3 + CloudFront**: Upload to S3 bucket and serve via CloudFront
- **Any static hosting**: The files are completely static and work on any web server

## Customization

### Colors

The color scheme matches the Digital Vision Board app theme (deep purple). To customize colors, edit CSS variables in `src/App.css`:

```css
:root {
  --primary-color: #673AB7;
  --primary-dark: #512DA8;
  --primary-light: #9575CD;
  /* ... */
}
```

### Content

Edit `src/App.tsx` to update:
- Hero section text
- Feature descriptions
- Board type information
- Privacy policy content

### Images

Replace image placeholders (currently showing gradient backgrounds) with actual screenshots:

1. Add images to `public/` directory
2. Update the image placeholders in `src/App.tsx` with `<img>` tags or background images

## Structure

```
canva-app-panel/
├── src/
│   ├── App.tsx          # Main React component with all content
│   ├── App.css          # Styles and responsive design
│   └── main.tsx         # React entry point
├── index.html           # HTML template
├── package.json         # Dependencies and scripts
├── vite.config.ts       # Vite configuration
└── README.md            # This file
```

## Technologies

- **React 19**: UI library
- **TypeScript**: Type safety
- **Vite**: Build tool and dev server
- **CSS**: Custom styles with CSS variables

## License

This marketing site is part of the Digital Vision Board project.
