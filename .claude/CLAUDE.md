Use jcodemunch-mcp for code lookup whenever available. Prefer symbol search, outlines, and targeted retrieval over reading full files.

## Refactor öncesi audit
Büyük bir dosyayı/sınıfı/sistemi yeniden yazmadan veya kaldırmadan önce, mevcut kodun TÜM sorumluluklarını listele: shortcut'lar, signal/slot/Action'lar, context property'leri, QSettings/config key'leri, CLI argümanları/env var'lar, fallback davranışları (loading/error), lifecycle hook'ları, sub-component'ler. Plan'da "bunlar nereye taşınacak?" sözünü ver, sonra implementasyona geç. Reactive bug-fix yerine proactive coverage — kullanıcı "şu da kaybolmuş" demek zorunda kalmasın.

## Belge teslimlerinde otomatik watermark temizliği
Kullanıcıya bir BELGE çıktısı (metin/markdown/PDF/Word/DOCX/ODT/HTML dosyası veya kopyalanmaya hazır uzun metin bloğu) ürettiğimde, ona teslim etmeden ÖNCE watermarks-remover'dan geçir — kullanıcı hatırlatmak zorunda kalmasın. Kod dosyaları, config, script veya normal sohbet cevapları bu kapsamda DEĞİL; sadece kullanıcının paylaşacağı/yayınlayacağı belge çıktıları.

Dosya için (servis gerekmez, saf Python):
`python3 ~/watermarks-remover/service/scripts/clean_file.py <dosya> -o <dosya.temiz>`
İçerik istatistiksel (Layer B) rewrite gerektiriyorsa ayrıca teklif et; Layer A (görünmez Unicode) + dosya metadata'sı her zaman otomatik uygula. Temizlik yapıldığını tek satır belirt, süreç için izin isteme.
# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

## public-apis kataloğu
Bir projeye veri kaynağı / hazır API gerektiğinde (hava durumu, döviz, geocoding, anime, finans, açık veri...) **web araması yapmadan önce** `public-apis` skill'ine bak: `~/.claude/skills/public-apis/`. Sorgu: `pa <terim>`, `pa -n <terim>` (anahtarsızlar), `pa -c <Kategori>`, `pa -u` (tazele). 1716 API yerelde TSV olarak aranabilir.

## Kurulu ama kullanılmayan araçlar — tetikleyiciler
Denetim: `~/.claude/ARACLAR.md` (2026-08-31). Aşağıdakiler kurulu ve bedava; refleks haline getir:

- **context7 MCP** → bir kütüphane/framework/SDK/CLI hakkında API, config, sürüm veya kurulum sorusu geldiğinde eğitim verisinden cevap verme, `resolve-library-id` + `query-docs` çağır. React/Vite/Tailwind/shadcn/Supabase/Stripe stack'inde varsayılan.
- **playwright MCP** → bir site 403/bot koruması verdiğinde, JS ile render olan içerik gerektiğinde veya fiyat/veri kazıma lazım olduğunda WebFetch'te ısrar etme, tarayıcıyı sür.
- **huggingface-skills** → model seçimi, YOLO/vision eğitimi, fine-tune, GGUF/yerel çalıştırma, VRAM hesabı, HF Jobs. AI Grand Prix ve TEKNOFEST forklift işlerinde ilk başvurulacak yer (`huggingface-best`, `huggingface-vision-trainer`, `hf-mem`, `huggingface-local-models`).
- **animasyon + frontend skill seti** → landing page / SaaS arayüzü yaparken `frontend-design`, `apple-design`, `emil-design-eng`; hareket eklerken `animate`, mevcut hareketi eleştirirken `review-animations`, kod tabanını tararken `improve-animations`.
- **clangd-lsp** → Clonify'ın VTK/CGAL/Qt C++ işinde.
- **diagram-design** → mimari/akış şeması istendiğinde ASCII yerine.
- **jcodemunch** → kod arama kuralı zaten yukarıda; 21 çağrıda kalmış, gerçekten uygula.

## ECC — kurulu 68 agent / 230 skill / 94 komut / 122 kural (2026-09-01)
Hook'suz, modül seçmeli kuruldu. Bunları kullanmak için kullanıcının istemesini bekleme, tetikleyiciye göre kendin çağır:

- **Kod incelemesi gerektiğinde** → dile göre `*-reviewer` agent'ını çalıştır: `cpp-reviewer` (Clonify/VTK/CGAL/Qt), `python-reviewer`, `react-reviewer`, `typescript-reviewer`, `java-reviewer` (Spring/Quarkus'u kendi ayırt eder), `kotlin-reviewer`, `swift-reviewer`, `flutter-reviewer`, `php-reviewer`, `fsharp-reviewer`, `go-reviewer`, `rust-reviewer`, `django-reviewer`, `fastapi-reviewer`, `vue-reviewer`, `csharp-reviewer`, `database-reviewer` (Postgres/Supabase), `mle-reviewer` (training/serving), `rag-pipeline-reviewer`, `security-reviewer`, `network-config-reviewer`.
- **Derleme / çalışma zamanı hatasında** → tahmin etme, `*-build-resolver` agent'ına ver: `cpp-build-resolver` (CMake+linker+template), `pytorch-build-resolver` (tensor shape, CUDA, DataLoader, AMP), `react-build-resolver` (Vite/webpack/Next), `java-build-resolver` (Maven/Gradle), `kotlin-build-resolver`, `swift-build-resolver` (Xcode/SPM), `dart-build-resolver`, `go-build-resolver`, `rust-build-resolver`, `django-build-resolver`, `harmonyos-app-resolver` (ArkTS/ArkUI).
- **Dile özel kod yazarken/refactor ederken** → önce ilgili skill'i aç: `cpp-coding-standards`, `cpp-testing`, `pytorch-patterns`, `python-patterns`/`python-testing`, `react-patterns`/`react-performance`/`react-testing`, `laravel-patterns`/`laravel-security`/`laravel-tdd`, `springboot-*`, `quarkus-*`, `kotlin-patterns`/`kotlin-coroutines-flows`/`kotlin-ktor-patterns`, `swiftui-patterns`/`swift-concurrency-6-2`, `dart-flutter-patterns`, `postgres-patterns`, `prisma-patterns`, `vite-patterns`, `nextjs-turbopack`, `docker-patterns`, `kubernetes-patterns`.
- **Performans / gecikme işi** → `latency-critical-systems`, `benchmark-methodology`, `benchmark-optimization-loop`, `parallel-execution-optimizer`, `data-throughput-accelerator`. Drone (AI Grand Prix) ve forklift işlerinde varsayılan.
- **Ajan/harness işi** → `agent-eval`, `eval-harness`, `agent-architecture-audit`, `context-budget` (kendi kurulumumun token maliyetini ölçmek için), `skill-stocktake`.
- **Diğer refleksler** → `silent-failure-hunter` (yutulan hata avı), `refactor-cleaner` (ölü kod), `type-design-analyzer`, `spec-miner` (brownfield'dan spec), `santa-method` (yayına çıkacak çıktıda iki bağımsız reviewer), `codebase-onboarding` (yeni repo), `taste` (müzik videosu/edit yönü), `homelab-wireguard-vpn`/`homelab-pihole-dns` (VPS+Tailscale işleri).
- **Slash komutlar** → `/cpp-review` `/cpp-build` `/cpp-test` `/flutter-review` `/kotlin-build` `/gradle-build` `/react-review` `/python-review` `/rust-review` `/go-review` `/build-fix` `/quality-gate` `/test-coverage` `/refactor-clean` `/review-pr` `/context-budget` `/skill-health`.
- **`~/.claude/rules/ecc/<dil>/`** → 22 dil için kural dosyaları. Context'e otomatik girmiyor; o dilde iş yaparken ilgili dosyayı açıkça oku (`hooks.md`, `security.md`, `testing.md` vb).

KULLANMA (kurulumda bağımlılık zorlamasıyla geldi, pasif): `continuous-learning-v2` ve `gateguard` → claude-mem + context-mode aynı işi yapıyor, çakışma çıkarır. `unified-memory` → MEMORY.md + claude-mem var. `healthcare-*`, `hipaa-compliance` → alakasız.
`ecc repair` / `ecc auto-update` ÇALIŞTIRMA — kurulum kasten hook'suz, bunlar hook'ları ve silinen dosyaları geri getirir. Ayrıntı: [[project-ecc-install]].
