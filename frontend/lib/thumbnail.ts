const THUMB_WIDTH = 200;
const THUMB_QUALITY = 0.7;

export function makeThumbnail(dataUrl: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => {
      const scale = THUMB_WIDTH / img.width;
      const h = Math.round(img.height * scale);
      const canvas = document.createElement('canvas');
      canvas.width = THUMB_WIDTH;
      canvas.height = h;
      canvas.getContext('2d')!.drawImage(img, 0, 0, THUMB_WIDTH, h);
      resolve(canvas.toDataURL('image/jpeg', THUMB_QUALITY));
    };
    img.onerror = reject;
    img.src = dataUrl;
  });
}
