# timon.clipboard (1.20.0): turns tesseract TSV into clean text lines.
# Drops what screenshots of apps typically turn into junk: low-confidence
# words, icon glyphs read as symbols next to labels ("£ Dynamic QR Code",
# "@ Top location"), and lines that are only symbols or a stray letter.
#   tesseract img - tsv | awk -f ocr-clean.awk
BEGIN { FS = "\t"; n = 0; out = 0; lastBlock = "" }
function alnum(t,   s) { s = t; return gsub(/[[:alnum:]]/, "", s) }
# A real word or number. An icon right next to a label drags the label's
# confidence down too ("Total" read at 22 % next to a chart icon), so these
# are never dropped for low confidence, only junk is.
function wordlike(t) { return t ~ /^[("'\[]?([[:alpha:]][[:alpha:]'’-]+|[[:digit:]][[:digit:].,:\/%-]*)[)"'\].,:;!?]*$/ && alnum(t) >= 2 }
# A word at the edge of a line that is an icon read as text: no letter or
# digit at all; or a short / non-word token set apart from the label by an
# icon-sized gap (wider than 0.8 line heights; a normal space is ~0.3); or a
# token mixing symbols that the OCR isn't sure about.
function edgeJunk(i, j,   t, gap) {
  t = W[i]
  if (alnum(t) == 0) return 1
  if (!wordlike(t) && t ~ /[^[:alnum:]]/ && C[i] < 60) return 1
  if (j < 1 || j > n) return 0
  gap = (i < j) ? L[j] - (L[i] + X[i]) : L[i] - (L[j] + X[j])
  return (length(t) <= 2 || !wordlike(t)) && gap >= 0.8 * H[j]
}
function flush(   i, a, b, s, sum, cnt, chars) {
  if (n == 0) return
  a = 1; b = n
  while (a <= b && edgeJunk(a, a < b ? a + 1 : 0)) a++
  while (b >= a && edgeJunk(b, b > a ? b - 1 : 0)) b--
  s = ""; sum = 0; cnt = 0; chars = 0
  for (i = a; i <= b; i++) { s = s (s == "" ? "" : " ") W[i]; sum += C[i]; cnt++; chars += alnum(W[i]) }
  if (cnt > 0 && chars >= 2 && (sum / cnt >= 55 || wordlike(W[a]))) {
    # one line per text line (no blank lines between blocks)
    print s; out = 1; lastBlock = block
  }
  n = 0
}
$1 == 5 {
  key = $3 " " $4 " " $5
  if (key != cur) { flush(); cur = key; block = $3 }
  t = $12; gsub(/^[[:space:]]+|[[:space:]]+$/, "", t)
  if (t == "" || ($11 + 0 < 50 && !wordlike(t))) next
  n++; W[n] = t; C[n] = $11 + 0; L[n] = $7 + 0; X[n] = $9 + 0; H[n] = $10 + 0
}
END { flush() }
