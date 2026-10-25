import { supabase } from './supabase';

export function defectArchiveName(defect) {
  const reported = new Date(defect.created_at);
  if (!defect.created_at || Number.isNaN(reported.getTime())) {
    throw new Error('The original defect date is missing or invalid.');
  }
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Europe/London', year: 'numeric', month: '2-digit', day: '2-digit'
  }).formatToParts(reported);
  const part = type => parts.find(p => p.type === type).value;
  const safe = value => String(value ?? '').replace(/[^a-zA-Z0-9_-]/g, '');
  const unit = safe(defect.train_number), coach = safe(defect.coach_number);
  if (!unit || !coach) throw new Error('The unit or coach number is missing.');
  return `Unit-${unit}_Coach-${coach}_${part('day')}-${part('month')}-${part('year')}.zip`;
}

export function imageEntryName(photo, index, mime = '') {
  // Numbered names avoid collisions and retain the original photo ordering.
  const match = String(photo.image_path || '').split('/').pop().match(/\.([a-zA-Z0-9]{1,10})$/);
  const types = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp',
    'image/heic': 'heic', 'image/heif': 'heif', 'image/gif': 'gif',
    'image/avif': 'avif', 'image/bmp': 'bmp', 'image/tiff': 'tiff' };
  const extension = match?.[1]?.toLowerCase() || types[mime.toLowerCase().split(';')[0]] || 'bin';
  return `Photo-${String(index + 1).padStart(3, '0')}.${extension}`;
}

export async function downloadDefectImages(defect) {
  const filename = defectArchiveName(defect);
  const photos = [...(defect.defect_images || defect.photos || [])]
    .sort((a, b) => (a.display_order || 0) - (b.display_order || 0));
  if (!photos.length) throw new Error('This defect has no images to download.');
  const { default: JSZip } = await import('jszip');
  const zip = new JSZip();
  // Fetch sequentially to avoid a burst of storage requests. Keep original bytes,
  // including HEIC images: the ZIP download does not convert or resize anything.
  for (let i = 0; i < photos.length; i++) {
    try {
      const { data, error } = await supabase.storage.from('defect-images').download(photos[i].image_path);
      if (error || !data?.size) throw new Error(error?.message || 'The stored image is empty.');
      zip.file(imageEntryName(photos[i], i, data.type), await data.arrayBuffer(), { binary: true });
    } catch (error) {
      throw new Error(`Image ${i + 1} could not be downloaded. No ZIP was saved. ${error.message || 'Please try again.'}`);
    }
  }
  // Images are already compressed; STORE avoids unnecessary CPU/battery usage.
  const blob = await zip.generateAsync({ type: 'blob', compression: 'STORE' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  try {
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
  } finally {
    link.remove();
    // Allow mobile browsers time to start reading the Blob before releasing it.
    setTimeout(() => URL.revokeObjectURL(url), 60000);
  }
}
