import { supabase } from './supabase';

// All processing stays in the browser. Existing storage permissions still apply.
async function decodeImage(blob) {
  const url = URL.createObjectURL(blob);
  try {
    return await new Promise((resolve, reject) => {
      const image = new Image();
      image.onload = () => resolve(image);
      image.onerror = () => reject(new Error('Image format could not be decoded.'));
      image.src = url;
    });
  } finally {
    URL.revokeObjectURL(url);
  }
}

async function photoForPdf(photo) {
  // Download afresh using the current session, not an expired preview URL.
  const { data, error } = await supabase.storage.from('defect-images').download(photo.image_path);
  if (error || !data?.size) throw new Error(error?.message || 'The stored image is empty.');
  let image;
  try {
    image = await decodeImage(data);
  } catch (error) {
    if (!/\.(heic|heif)$/i.test(photo.image_path) && !/hei[cf]/i.test(data.type)) throw error;
    const { default: heic2any } = await import('heic2any');
    const converted = await heic2any({ blob: data, toType: 'image/jpeg', quality: 0.92 });
    image = await decodeImage(Array.isArray(converted) ? converted[0] : converted);
  }
  const scale = Math.min(1, 2200 / Math.max(image.naturalWidth, image.naturalHeight));
  const canvas = document.createElement('canvas');
  canvas.width = Math.max(1, Math.round(image.naturalWidth * scale));
  canvas.height = Math.max(1, Math.round(image.naturalHeight * scale));
  const context = canvas.getContext('2d');
  if (!context) throw new Error('This browser cannot prepare images for PDF.');
  context.fillStyle = '#fff';
  context.fillRect(0, 0, canvas.width, canvas.height);
  context.drawImage(image, 0, 0, canvas.width, canvas.height);
  const result = { data: canvas.toDataURL('image/jpeg', 0.92), width: canvas.width, height: canvas.height };
  canvas.width = canvas.height = 1;
  return result;
}

// Rasterise description lines at print resolution so browser-supported Unicode
// is preserved without relying on the limited built-in PDF font character set.
function descriptionLines(text) {
  const canvas = document.createElement('canvas');
  canvas.width = 1740;
  canvas.height = 68;
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('This browser cannot prepare report text.');
  ctx.font = '39px Arial, sans-serif';
  const lines = [];
  for (const paragraph of String(text || '').replace(/\r\n?/g, '\n').split('\n')) {
    let line = '';
    for (const token of paragraph.replace(/\t/g, '    ').split(/(\s+)/)) {
      if (ctx.measureText(line + token).width <= 1730) { line += token; continue; }
      if (line.trim()) { lines.push(line.trimEnd()); line = ''; }
      for (const char of token.trimStart()) {
        if (ctx.measureText(line + char).width > 1730 && line) { lines.push(line); line = ''; }
        line += char;
      }
    }
    lines.push(line.trimEnd());
  }
  return { canvas, ctx, lines };
}

export async function downloadDefectReport(defect) {
  const reported = new Date(defect.created_at);
  if (!defect.created_at || Number.isNaN(reported.getTime())) {
    throw new Error('The original reported date is missing or invalid. No PDF was downloaded.');
  }
  const { jsPDF } = await import('jspdf');
  const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4', compress: true });
  const margin = 18, width = 174, bottom = 276;
  const date = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Europe/London', day: '2-digit', month: 'long', year: 'numeric',
    hour: '2-digit', minute: '2-digit', hour12: false, timeZoneName: 'short'
  }).format(reported);
  let y;
  function header() {
    doc.setTextColor(15, 23, 42);
    doc.setFont('helvetica', 'bold'); doc.setFontSize(20);
    doc.text('D&V defect report', margin, 24);
    doc.setFontSize(12);
    doc.text(`Unit ${defect.train_number}     Coach ${defect.coach_number}`, margin, 35);
    doc.setFont('helvetica', 'normal'); doc.setFontSize(10);
    doc.text(`First reported: ${date}`, margin, 43);
    doc.setDrawColor(203, 213, 225); doc.line(margin, 49, 192, 49);
    y = 59;
  }
  function nextPage() { doc.addPage(); header(); }
  function heading(label) {
    doc.setFont('helvetica', 'bold'); doc.setFontSize(12);
    doc.setTextColor(15, 23, 42); doc.text(label, margin, y); y += 7;
  }
  header();
  heading('Description');
  const { canvas, ctx, lines } = descriptionLines(defect.description);
  for (const line of lines) {
    if (y + 6.8 > bottom) { nextPage(); heading('Description (continued)'); }
    if (line) {
      ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.fillStyle = '#0f172a'; ctx.textBaseline = 'top'; ctx.fillText(line, 0, 10);
      doc.addImage(canvas.toDataURL('image/png'), 'PNG', margin, y, width, 6.8);
    }
    y += 6.8;
  }
  canvas.width = canvas.height = 1;
  y += 10;
  const photos = [...(defect.defect_images || defect.photos || [])]
    .sort((a, b) => (a.display_order || 0) - (b.display_order || 0));
  if (!photos.length) {
    if (y + 18 > bottom) nextPage();
    heading('Photographs');
    doc.setFont('helvetica', 'normal'); doc.setFontSize(11);
    doc.text('No photographs attached to this report.', margin, y);
  }
  for (let i = 0; i < photos.length; i++) {
    let photo;
    try { photo = await photoForPdf(photos[i]); }
    catch (error) {
      throw new Error(`Photo ${i + 1} could not be included. No PDF was downloaded. ${error.message || 'Please retry or check the original image.'}`);
    }
    // Fit without cropping or stretching; keep caption and photo together.
    const scale = Math.min(width / photo.width, 155 / photo.height);
    const w = photo.width * scale, h = photo.height * scale;
    if (y + 9 + h > bottom) nextPage();
    heading(`Photograph ${i + 1} of ${photos.length}`);
    doc.addImage(photo.data, 'JPEG', margin + (width - w) / 2, y, w, h);
    y += h + 18; // Generous separation before the next photograph.
  }
  const total = doc.getNumberOfPages();
  for (let page = 1; page <= total; page++) {
    doc.setPage(page); doc.setFont('helvetica', 'normal'); doc.setFontSize(9);
    doc.setTextColor(100, 116, 139);
    doc.text(`Page ${page} of ${total}`, 192, 287, { align: 'right' });
  }
  const safe = value => String(value || '').replace(/[^a-zA-Z0-9_-]/g, '');
  const datePart = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/London', year: 'numeric', month: '2-digit', day: '2-digit' }).format(reported);
  await doc.save(`DV_Unit-${safe(defect.train_number)}_Coach-${safe(defect.coach_number)}_${datePart}_${safe(defect.id)}.pdf`, { returnPromise: true });
}
