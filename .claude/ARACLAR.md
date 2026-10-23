# Araç Envanteri — kurulu MCP'ler, skiller, pluginler

Son denetim: **2026-08-31** · Kaynak: `~/.claude.json`, `~/.claude/skills/`, `~/.claude/plugins/`
Kullanım sayıları `~/.claude/projects/**/*.jsonl` (1 GB, 1233 transcript) üzerinden sayıldı.

---

## 1. MCP Serverlar

| Server | Kapsam | Çağrı | Durum |
|---|---|---:|---|
| context-mode | plugin | 1803 | ⭐ ana iş atı |
| arxiv-latex | global | 344 | ✅ aktif (TEKNOFEST/paper okuma) |
| codebase-memory-mcp | global | 49 | ✅ aktif |
| anilist | proje | 24 | ✅ aktif |
| jcodemunch | global+proje | 21 | ⚠️ **az** — CLAUDE.md "her zaman kullan" diyor ama 21 çağrı |
| claude_ai_Supabase | bağlı | 4 | ⚠️ az |
| claude-mem mcp-search | plugin | 1 | ⚠️ az |
| **context7** | global | **0** | ❌ **hiç kullanılmadı** |
| **playwright** | proje | **0** | ❌ **hiç kullanılmadı** |
| **graphify** | global | **0** | ❌ MCP olarak 0 (skill'i biliniyor) |
| godot | global+proje | 0 | 🔒 kullanılmıyor ama **bilerek tutuluyor** (kullanıcı kararı, 2026-08-31) |
| ~~sequential-thinking~~ | — | 0 | 🗑️ **kaldırıldı 2026-08-31** (extended thinking ile mükerrer) |

### Kaçırılan fırsatlar (somut)

- **context7** → güncel kütüphane dokümanı çeker. Kullanıcının stack'i React+Vite+Tailwind+
  shadcn+Supabase+Stripe; bu MCP tam ona göre. Her SaaS/frontend işinde eğitim verisinden
  cevap vermek yerine buraya sorulmalı.
- **playwright** → 2026-08-31'de akakçe/cimri/inceHesap 403 verdiğinde GPU fiyatları
  alınamadı. Playwright tam bunun için duruyordu, akla gelmedi. Bot korumalı site =
  Playwright refleksi.
- **sequential-thinking** → extended thinking ile mükerrer olduğu için **kaldırıldı (2026-08-31)**.
- **godot** → 0 kullanım ama kullanıcı kararıyla **duruyor**; olası oyun projesi için bekletiliyor.
  Tekrar denetimde "kullanılmıyor" diye yeniden önerme.

---

## 2. Skiller (`~/.claude/skills/`)

| Skill | Kurulum | Çağrı | Durum |
|---|---|---:|---|
| public-apis | 2026-08-31 | yeni | 🆕 1716 API yerel katalog |
| remove-ai-marks | 2026-08-17 | 0 (script elle) | ⚠️ skill olarak çağrılmıyor |
| graphify | 2026-08-30 | 0 | ❌ |
| codebase-memory | 2026-07-27 | 0 | ❌ (MCP'si kullanılıyor) |
| task-observer | 2026-08-17 | 0 | ❌ |
| find-skills | 2026-08-17 | 0 | ❌ |
| **animate** | 2026-08-17 | 0 | ❌ animasyon seti — 5 skill, hiçbiri kullanılmadı |
| **review-animations** | 2026-08-17 | 0 | ❌ |
| **improve-animations** | 2026-08-17 | 0 | ❌ |
| **find-animation-opportunities** | 2026-08-17 | 0 | ❌ |
| **animation-vocabulary** | 2026-08-17 | 0 | ❌ |
| **apple-design** | 2026-08-17 | 0 | ❌ frontend polish |
| **emil-design-eng** | 2026-08-17 | 0 | ❌ frontend polish |
| **ask-sonner** | 2026-08-17 | 0 | ❌ toast kütüphanesi |

**Not:** 2026-08-17'de 9 tane frontend/animasyon skill'i kuruldu, **hiçbiri bir kez bile
çalıştırılmadı.** Bunlar SaaS/landing page işinde (site-builder-v2 iş akışı) doğrudan
karşılığı olan araçlar — ilk frontend projesinde devreye girmeli.

---

## 3. Pluginler

| Plugin | Kurulum | Durum |
|---|---|---|
| context-mode | 2026-03-26 | ⭐ tek `enabledPlugins:true` olan; yoğun kullanımda |
| claude-mem | 2026-08-17 | ✅ hook'larla çalışıyor (session context) |
| superpowers | 2026-05-28 | ✅ brainstorming/writing-plans/subagent-driven kullanılıyor |
| **huggingface-skills** | 2026-05-28 | ❌ **30+ skill, 0 kullanım** |
| **diagram-design** | 2026-08-17 | ❌ 0 kullanım |
| **frontend-design** | 2026-05-28 | ⚠️ 1 kullanım |
| **clangd-lsp** | 2026-02-23 | ❌ 0 — C/C++ (Clonify VTK/CGAL işi) için duruyor |
| learning-output-style | 2026-05-28 | ⚠️ **çelişki** — aktif ama kullanıcı ana özelliğini (★ Insight blokları) memory ile kapattırdı |

### huggingface-skills — en büyük kayıp

Kullanıcının **AI Grand Prix (Anduril drone racing)** ve **TEKNOFEST forklift** projeleri var;
YOLO eğitimi, VIO, model seçimi gerekiyor. Bu plugin tam bunun için:

- `hf-cli` — model/dataset indirme, upload, HF Jobs
- `huggingface-llm-trainer` — TRL/Unsloth ile bulut GPU'da eğitim (yerel GPU gerekmez)
- `huggingface-vision-trainer` — görüntü modeli eğitimi (YOLO/keypoint için)
- `huggingface-best` — "bu iş için en iyi model hangisi" + benchmark karşılaştırma
- `huggingface-local-models` — GGUF/llama.cpp ile yerelde çalıştırma, quant seçimi
- `hf-mem` — model ağırlıklarının bellek ihtiyacını hesaplama (RTX 5070 Ti vs 9070 XT
  kararında doğrudan işe yarardı)
- `huggingface-papers` / `huggingface-community-evals` — paper okuma, eval

---

## 4. Aksiyon önerileri

**Kaldırıldı:** `sequential-thinking` (2026-08-31, user scope). Yedek: `~/.claude.json.bak-20260831`.
Geri eklemek: `claude mcp add sequential-thinking -s user -- npx -y @modelcontextprotocol/server-sequential-thinking`

**Bilerek tutuluyor:** `godot` — kullanım yok ama kullanıcı saklamak istedi.

**Devreye al (yüksek getiri, sıfır maliyet):** context7, playwright, huggingface-skills,
animasyon/frontend skill seti, clangd-lsp. Bunlar için `~/.claude/CLAUDE.md`'ye tetikleyici
kurallar eklendi — artık ilgili iş geldiğinde otomatik kullanılacak.

**Gözden geçir:** `learning-output-style` çıktı stili aktif ama kullanıcı Insight bloklarını
istemiyor. `/output-style` ile başka bir stile geçmek daha tutarlı olur.

**Yeniden denetim:** `pa`-benzeri sayım komutu:
```bash
grep -rohE '"name":"mcp__[a-zA-Z0-9_-]+__' ~/.claude/projects --include='*.jsonl' \
  | sed 's/"name":"mcp__//; s/__$//' | sort | uniq -c | sort -rn
```
