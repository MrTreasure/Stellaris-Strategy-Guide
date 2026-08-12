/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'export',
  // Emit dynamic pages as /guides/<slug>/index.html, which matches nginx's
  // directory fallback and Next's route pathname during a full navigation.
  trailingSlash: true,
  images: { unoptimized: true },
};

export default nextConfig;
