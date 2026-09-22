# PostgreSQL Daxili Mexanizmlər — Genişləndirilmiş Giriş

> Bu fayl əsas kursu (`postgresql-expert-kurs.md`) tamamlayan **əlavə material**dır. Məqsəd: PostgreSQL "pərdə arxasında" — yəni sən `INSERT`/`UPDATE`/`SELECT` yazanda server daxilində — nə baş verdiyini dərindən anlamaq. Bu mövzuların çoxu əsas kursda Faza 5, 7, 9, 10-da təfərrüatlı işlənəcək; bu fayl isə erkən mərhələdə "böyük şəkli" görmək üçündür.

---

## 1. Proses memarlığı — genişləndirilmiş diaqram

PostgreSQL **proses-əsaslıdır** (thread yox) — hər bağlantı, hər arxa-plan tapşırığı öz ayrıca əməliyyat sistemi prosesinə malikdir. Bunun üstünlüyü: bir proses çöksə, digərlərinə (adətən) təsir etmir — izolyasiya güclüdür.

```
                              ┌────────────────────────────┐
        Klient 1 ──────────► │                             │
        Klient 2 ──────────► │   postmaster (baş proses)   │
        Klient 3 ──────────► │   - server başladanda ilk   │
                              │     bu işə düşür            │
                              │   - digər prosesləri yaradır│
                              │   - biri çökərsə, bərpa edir│
                              └──────────────┬──────────────┘
                                             │ fork edir
           ┌──────────────┬─────────────────┼─────────────────┬──────────────┐
           ▼              ▼                 ▼                 ▼              ▼
     ┌───────────┐  ┌───────────┐   ┌───────────────┐  ┌────────────┐  ┌───────────┐
     │ Backend 1 │  │ Backend 2 │   │ Background     │  │ Checkpointer│  │ WAL Writer│
     │(Klient 1) │  │(Klient 2) │   │ Writer         │  │             │  │           │
     └───────────┘  └───────────┘   └───────────────┘  └────────────┘  └───────────┘

     ┌───────────────┐  ┌────────────────┐  ┌───────────┐  ┌───────────────────────┐
     │ Autovacuum     │  │ Stats Collector │  │ Logger    │  │ Archiver (arxivləmə   │
     │ Launcher +     │  │                 │  │           │  │ aktivdirsə)           │
     │ Worker-lər     │  │                 │  │           │  │                       │
     └───────────────┘  └────────────────┘  └───────────┘  └───────────────────────┘

     ┌──────────────────────┐   ┌──────────────────────┐
     │ WAL Sender            │   │ WAL Receiver          │  ← yalnız replikasiya
     │ (primary serverdə)    │   │ (standby serverdə)    │     qurulubsa aktivdir
     └──────────────────────┘   └──────────────────────┘
```

**Vacib qayda:** hər yeni klient qoşulanda `postmaster` ona ayrıca bir **backend proses** ayırır (thread yox, tam proses). Bu, bağlantı sayı çox olan sistemlərdə yaddaş baxımından bahalıdır — ona görə production-da adətən **connection pooler** (məs. PgBouncer) istifadə olunur (Faza 8-də görəcəyik).

---

## 2. Hər prosesin nə etdiyi — təfərrüatlı

### Postmaster
**Nə edir:** Server başlayanda ilk açılan prosesdir. Shared memory-ni (paylaşılan yaddaş sahəsini) ayırır, digər bütün prosesləri yaradır, server portunu dinləyir, yeni qoşulmaları qəbul edir.
**Analogiya:** bir restoranın meneceri kimi düşün — özü yemək bişirmir, amma aşpazları (backend-ləri) işə salır, kimsə xəstələnsə (çöksə) əvəzini tapır, restoranın ümumi işini idarə edir.

### Backend proses
**Nə edir:** Hər klient bağlantısı üçün ayrıca yaranır. Sənin göndərdiyin SQL-i o icra edir, nəticəni o qaytarır.
**Vacib:** Bir backend çökərsə (məsələn, ciddi bug səbəbindən), postmaster bunu görür və **bütün digər backend-ləri də təhlükəsizlik üçün yenidən başladır** (shared memory-nin korlanma ehtimalına görə) — məhz buna görə production-da `FATAL`/`PANIC` xətaları ciddi qəbul edilir.

### Autovacuum (Launcher + Worker-lər)
**Nə edir:** Arxa planda avtomatik işə düşür, "dead tuple"-ları (aşağıda izah olunur) təmizləyir, həm də sorğu planlayıcısı (planner) üçün statistikanı yeniləyir.
**Niyə vacib:** Bu olmasa, cədvəllər zamanla "şişər" (bloat) — real datadan qat-qat böyük yer tutar, sorğular yavaşlayar. Faza 5.5-də dərindən görəcəyik.

### Background Writer
**Nə edir:** Yaddaşda (shared buffers-də) dəyişmiş, hələ diskə yazılmamış səhifələrə **"dirty pages"** deyilir. Bu proses onları tədricən, kiçik-kiçik hissələrlə diskə yazır.
**Niyə vacib:** Əgər bunu etməsə, dəyişikliklərin hamısı `checkpoint` anında bir dəfəyə yazılmalı olardı — bu, ani I/O "partlayışına" səbəb olardı. Background Writer bunu əvvəlcədən "hamarlayır".

### WAL Writer
**Nə edir:** WAL buferindəki qeydləri diskdəki WAL fayllarına yazır.

### Checkpointer
**Nə edir:** Müəyyən aralıqlarla (vaxt və ya WAL həcmi əsasında) **bütün** dirty page-ləri məcburi diskə yazır və "bu ana qədər hər şey təhlükəsiz diskdədir" işarəsi (checkpoint) qoyur.
**Niyə vacib:** Qəza bərpası (crash recovery) zamanı PostgreSQL yalnız **son checkpoint-dən sonrakı** WAL-ı təkrar oynatmalıdır — bütün tarixi yox. Checkpoint nə qədər tez-tez olsa, bərpa sürəti bir o qədər yaxşıdır, amma özü də I/O yükü yaradır — balans lazımdır (Faza 5/8).

### Stats Collector
**Nə edir:** Server fəaliyyəti haqqında statistika toplayır — neçə sətir oxunub/yazılıb, indekslər neçə dəfə istifadə olunub və s. (`pg_stat_*` view-ları buradan qidalanır).

### Logger
**Nə edir:** Server log mesajlarını (xətalar, xəbərdarlıqlar, yavaş sorğular və s.) fayla yazır. Diaqnostika üçün ilk baxılan yerdir.

### Archiver
**Nə edir:** Dolmuş WAL fayllarını uzunmüddətli yaddaşa (başqa disk, S3 və s.) köçürür — yalnız `archive_mode = on` olanda aktivdir.
**Niyə vacib:** **Point-in-Time Recovery** (keçmişdə istənilən ana qədər bərpa) və bəzi replikasiya üsulları bunsuz mümkün deyil (Faza 8-9).

### WAL Sender / WAL Receiver
**Nə edir:** Yalnız replikasiya qurulanda işə düşür. `WAL Sender` — primary serverdə, WAL-ı standby-a göndərir. `WAL Receiver` — standby serverdə, gələn WAL-ı qəbul edib tətbiq edir (Faza 9).

---

## 3. MVCC və "dead tuple" — dərin izah

PostgreSQL-in ən fundamental xüsusiyyətlərindən biri **MVCC**-dir (Multi-Version Concurrency Control — çox-versiyalı paralellik idarəsi). Sadə ifadə ilə: **eyni sətrin bir neçə versiyası eyni anda mövcud ola bilər.**

### Niyə belə edilir?

Fərz et ki, sən uzun bir `SELECT` icra edirsən, o vaxt başqası eyni cədvəldə `UPDATE` edir. Ənənəvi yanaşmada (kilidləmə ilə) sənin `SELECT`-in gözləməli olardı. PostgreSQL isə bunun əvəzinə: sənə sorğun **başladığı andakı** "şəkli" (snapshot) göstərir, digər tərəfdən `UPDATE` öz işini görməyə davam edir — **heç kim heç kimi bloklamır**. Bu, PostgreSQL-in ən böyük performans üstünlüklərindən biridir (Faza 7-də tam mexanizmi görəcəyik).

### Bu necə işləyir — `xmin` / `xmax`

Hər sətir versiyasının daxildə (görünməz) iki "sistem sütunu" var:
- **`xmin`** — bu versiyanı **yaradan** tranzaksiyanın ID-si.
- **`xmax`** — bu versiyanı **köhnəldən** (silən/dəyişdirən) tranzaksiyanın ID-si (əgər hələ aktivdirsə, boşdur).

**Misal — `UPDATE` addım-addım:**

```
Başlanğıc vəziyyət (tranzaksiya 100 yaratdı):

┌────┬────────┬───────┬──────┬──────┐
│ id │ name   │ price │ xmin │ xmax │
├────┼────────┼───────┼──────┼──────┤
│  1 │ Widget │ 10.00 │ 100  │  —   │   ← aktiv (canlı) versiya
└────┴────────┴───────┴──────┴──────┘
```

```sql
-- Tranzaksiya 101:
UPDATE products SET price = 12.00 WHERE id = 1;
```

```
Update-dən sonra — sətir "yerində" dəyişmir, YENİ versiya əlavə olunur:

┌────┬────────┬───────┬──────┬──────┐
│ id │ name   │ price │ xmin │ xmax │
├────┼────────┼───────┼──────┼──────┤
│  1 │ Widget │ 10.00 │ 100  │ 101  │   ← DEAD TUPLE (artıq heç kimə lazım deyil)
│  1 │ Widget │ 12.00 │ 101  │  —   │   ← yeni canlı versiya
└────┴────────┴───────┴──────┴──────┘
```

Yəni: köhnə sətir **silinmir**, sadəcə "bu, tranzaksiya 101-dən sonra artıq etibarsızdır" (`xmax = 101`) işarəsi qoyulur, yeni sətir isə ayrıca əlavə olunur. Əgər həmin anda başqa bir tranzaksiya (məsələn 99, `UPDATE`-dən əvvəl başlamış) hələ işləyirsə, o, `xmax`-ı gördüyü anlıq tranzaksiya ID-sinə görə **köhnə versiyanı** görməyə davam edir — dəyişiklikdən xəbəri belə olmur. Bu, MVCC-nin gücüdür.

### Dead tuple problemi

Yuxarıdakı `id=1` üçün indi **iki fiziki sətir** diskdə var, amma məntiqi olaraq bir sətir mövcuddur. Bir cədvəldə çoxlu `UPDATE`/`DELETE` gedirsə, bu cür "ölü" versiyalar tədricən yığılır — cədvəl fiziki olaraq real ehtiyacdan qat-qat böyük yer tutmağa başlayır. Buna **bloat** (şişmə) deyilir.

**`VACUUM`** məhz bunun üçündür: heç bir aktiv tranzaksiyaya lazım olmayan dead tuple-ları tapıb, onların tutduğu yeri "yenidən istifadə üçün azad" edir (diskdən fiziki kiçilmə həmişə olmur — bax `VACUUM` vs `VACUUM FULL`, Faza 5.5-də tam görəcəyik). **Autovacuum** bunu arxa planda avtomatik, sənin heç nə etmədən edir.

---

## 4. WAL (Write-Ahead Log) — dərin izah

### Axın diaqramı

```
1) Klient dəyişiklik göndərir (UPDATE ...)
              │
              ▼
2) Backend proses dəyişikliyi əvvəlcə WAL BUFFERİNƏ (yaddaşda) yazır
              │
              ▼
3) Tranzaksiya COMMIT olanda → WAL buferi DİSKƏ fsync edilir (WAL Writer / backend)
   (bu an artıq "təhlükəsiz yazılıb" sayılır — COMMIT müştəriyə "OK" qaytarır)
              │
              ▼
4) Əsl data faylındakı səhifə YADDAŞDA (shared buffers-də) dəyişir,
   amma diskə DƏRHAL yazılmır
              │
              ▼
5) Background Writer / Checkpointer bu "dirty page"-i bir az sonra,
   öz vaxtında diskdəki əsl data faylına yazır
```

### Niyə bu ardıcıllıq?

Diqqət et: **WAL əvvəl, data faylı sonra** yazılır — adının səbəbi elə budur ("Write-**Ahead**" Log). Bunun məntiqi:

- WAL yazısı **ardıcıl (sequential)** diskə yazmadır — çox sürətlidir.
- Data faylına yazma isə **təsadüfi (random)** yerlərə ola bilər — yavaşdır.
- Əgər hər `COMMIT`-də dərhal data faylını yeniləməli olsaydıq, performans çox aşağı olardı.
- WAL sayəsində: `COMMIT` yalnız WAL-ın diskə yazılmasını gözləyir (sürətli), əsl data faylının yenilənməsi isə arxa planda, rahat vaxtda baş verir.

### Qəza bərpası (crash recovery) necə işləyir?

Server qəflətən çöksə (işıq kəsilsə və s.):
1. Yenidən açılanda PostgreSQL son **checkpoint**-i tapır (yəni "bu ana qədər data faylı hökmən doğrudur" nöqtəsi).
2. Checkpoint-dən sonrakı bütün WAL qeydlərini sırayla **yenidən oynadır** (replay) — beləliklə commit olunmuş, amma hələ data faylına köçürülməmiş dəyişikliklər bərpa olunur.
3. Commit olunmamış (yarımçıq) tranzaksiyalar sadəcə atılır.

Nəticə: **heç vaxt** commit olunmuş data itmir, sistem həmişə tutarlı vəziyyətə qayıdır. Buna **durability** (D hərfi ACID-də) deyilir.

---

## 5. Bütün axın bir yerdə — ən sadə dillə, addım-addım

Bu bölmə yuxarıdakı hər şeyi **tək bir hekayəyə** birləşdirir. Əvvəlcə iki əsas yeri yadına sal:

- **RAM** — sürətli, amma işıq kəsilsə **hər şey silinir**.
- **SSD (fiziki disk)** — yavaş, amma işıq kəsilsə belə **qalır**.

PostgreSQL-in data qovluğunda iki əsas alt-qovluq var:
```
data_directory/
  base/     ← cədvəllərin əsl datası (products, orders, ...)
  pg_wal/   ← WAL faylları ("nə edildi" gündəliyi)
```

İndi `UPDATE products SET price = 12.00 WHERE id = 1;` yazıb Enter vuranda:

**1. Sətir tapılır.** Backend əvvəlcə RAM-dakı ortaq keşə (`shared_buffers`) baxır. `id=1`-in səhifəsi orda varsa oxuyur, yoxdursa SSD-dəki `base/`-dan oxuyub RAM-a gətirir.

**2. Dəyişiklik RAM-da edilir.** Backend bu RAM-dakı səhifəni dəyişir: köhnə sətir "ölü" (dead tuple) işarələnir, yeni sətir əlavə olunur. Bu səhifə indi **dirty** sayılır (RAM-da yeni, SSD-də hələ köhnə). **`base/`-dəki fayl bu addımda hələ toxunulmayıb!**

**3. Dəyişikliyin qeydi RAM-dakı WAL buferinə yazılır.** Bu, `shared_buffers`-dən **ayrı**, kiçik bir RAM sahəsidir — "filan səhifədə bu dəyişiklik oldu" kimi qısa qeyd (SQL mətni yox, fiziki dəyişiklik qeydi).

**4. `COMMIT` olur.** `psql`-də defolt rejim — **avtomatik commit**: hər cümləni yazıb Enter vuranda, PostgreSQL onu görünməz şəkildə `BEGIN; ...; COMMIT;` içinə salır. `COMMIT` anında WAL buferindəki qeyd **SSD-dəki `pg_wal` qovluğuna, `fsync` ilə** yazılır. Yalnız bundan sonra sənə "UPDATE 1" cavabı qayıdır.

> **`fsync` nədir:** proqram fayla "yazdım" desə də, bu baytlar əvvəlcə əməliyyat sisteminin öz RAM keşinə düşür (sürət üçün), fiziki SSD-yə gec köçürülə bilər. `fsync` — "bunu İNDİ, fiziki olaraq SSD-yə köçür, gözləmə" əmridir. Analoji: məktubu ofisin çıxış qutusuna qoymaq (yazıldı, hələ göndərilməyib) ilə poçt maşınının onu aparması (artıq təhlükəsiz, geri dönməz) arasındakı fərq.

**5. Bu andan dəyişiklik rəsmi və daimidir.** Server elə bu saniyə çöksə belə, itmir — `pg_wal`-da qeyd var, server açılanda onu oxuyub tətbiq edəcək.

**6. Bir az sonra, tamam ayrıca.** Background Writer (davamlı, kiçik-kiçik) və ya Checkpointer (dövri, hamısını bir yerdə) RAM-dakı dirty page-i götürüb **SSD-dəki `base/` qovluğundakı əsl cədvəl faylına** yazır. İndi `pg_wal` və `base/` sinxrondur.

**Niyə 4-cü və 6-cı addım ayrıdır?** WAL-a yazmaq **ardıcıl və sürətlidir**, əsas fayla yazmaq isə **təsadüfi yerlərə, yavaşdır**. Əgər hər `COMMIT` əsas faylın da yenilənməsini gözləsəydi, sistem çox yavaş olardı. WAL sayəsində `COMMIT` yalnız sürətli WAL yazısını gözləyir, əsas faylın yenilənməsi isə arxa planda, rahat vaxtda baş verir.

**Konkret `xmin`/`xmax` nümunəsi** (2-ci addımdakı "dirty page"in içi): sətir əvvəlcə tranzaksiya `100` tərəfindən yaradılıb (`xmin=100, xmax=boş`). `101` nömrəli tranzaksiya `UPDATE` edəndə: köhnə sətrin `xmin`-i **dəyişmir** (100 olaraq qalır — onu kim yaratdığı heç vaxt dəyişməz), sadəcə `xmax=101` əlavə olunur ("101 məni köhnəltdi"). Yeni sətrin isə `xmin=101` (onu 101 yaratdı), `xmax` boşdur. Diqqət: köhnə sətrin **yeni `xmax`-ı** ilə yeni sətrin **`xmin`-i** həmişə **eyni ədəddir** — çünki ikisini də məhz **eyni** UPDATE tranzaksiyası yaradıb.

### Snapshot — "mən başlayanda kim artıq bitmişdi" siyahısı

Sətir versiyalarının görünüb-görünməməsini müəyyən edən mexanizmə **snapshot** deyilir. Bu, data yox, sadəcə RAM-da saxlanan **kiçik bir siyahıdır**: "mənim tranzaksiyam başlayan anda, hansı tranzaksiya ID-ləri artıq commit olunmuşdu". `shared_buffers`-lə heç bir əlaqəsi yoxdur — tamam ayrı, kiçik bir metadata strukturudur.

Hər sətir versiyasına baxanda (`xmin`/`xmax`-ına görə), sadəcə bu siyahıya sual verilir: "bunu yaradan/köhnəldən tranzaksiya mənim 'artıq bitib' siyahımdadırmı?" Bu sayədə, sənin sorğun işlədiyi müddətdə başqaları yeni dəyişikliklər etsə belə, sən sorğunun **başladığı andakı** sabit "şəklə" baxmağa davam edirsən — nəticələr ortasında ziddiyyət yaranmır.

### Digər əməliyyatların axını — müqayisə

- **`SELECT`** — ən "ucuzu": snapshot götürülür, `shared_buffers`/`base/`-dən səhifə oxunur, `xmin`/`xmax` snapshot-a görə süzülür, nəticə qaytarılır. **Heç nə dəyişmir** — dirty page yox, WAL yox, fsync yox.
- **`INSERT`** — `UPDATE`-in "sadələşdirilmişi": köhnə heç nə yoxdur, sadəcə yeni sətir yaranır (`xmin=bu tranzaksiya`, `xmax=boş`), səhifə dirty olur, WAL-a yazılır, `COMMIT`-də fsync olunur, sonra Background Writer/Checkpointer `base/`-ə köçürür.
- **`DELETE`** — yeni sətir **yaranmır**, mövcud sətrin sadəcə `xmax`-ına bu tranzaksiyanın ID-si yazılır ("mən sildim" işarəsi). Qalanı (dirty page → WAL → fsync → background writer) eyni. Sətir fiziki olaraq hələ diskdədir, `VACUUM` gələnə qədər dead tuple kimi qalır.
- **`CREATE TABLE`** — iki şey olur: (1) `base/`-də yeni, boş fiziki fayl yaradılır (bu da WAL-a qeyd olunur), (2) cədvəlin təsviri PostgreSQL-in öz **sistem cədvəllərinə** (`pg_class`, `pg_attribute`) yazılır — bu da texniki cəhətdən adi bir `INSERT`dir (dirty page → WAL → fsync → background writer, sadəcə sənin cədvəlinə yox, sistem cədvəllərinə).

| Əməliyyat | Yeni sətir versiyası? | Dirty page? | WAL? |
|---|---|---|---|
| `SELECT` | yox | yox | yox |
| `INSERT` | bəli (1 yeni) | bəli | bəli |
| `UPDATE` | bəli (köhnəsi dead olur) | bəli | bəli |
| `DELETE` | yox (yalnız `xmax` qoyulur) | bəli | bəli |
| `CREATE TABLE` | bəli (sistem cədvəllərində) | bəli | bəli |

---

## 6. Shared Buffers — qısaca

`shared_buffers` — bütün backend proseslərin **birgə** istifadə etdiyi yaddaş sahəsidir, diskdəki səhifələrin keşidir. Bir sətri oxumaq istəyəndə, PostgreSQL əvvəlcə bu keşə baxır (`shared hit`), yalnız orda yoxdursa diskdən oxuyur (`read`). `EXPLAIN (ANALYZE, BUFFERS)` işlədəndə gördüyün `shared hit`/`read` statistikası məhz buradan gəlir (Faza 5.1-də görəcəyik).

**Strukturu:** `shared_buffers` **BİR dənə**, sabit ölçülü (məs. default 128MB) hovuzdur — "hər səhifə üçün ayrıca 128MB" demək **deyil**. Bu hovuz daxili olaraq çoxlu **8KB-lıq yuvaya** bölünür (128MB/8KB ≈ 16384 yuva), hər yuva bir diskdəki səhifənin surətini saxlayır.

**128MB dolanda nə olur?** Yeni səhifə lazım olanda, ən az istifadə olunan yuva "qurban" seçilir (**clock-sweep** alqoritmi, LRU-ya bənzəyir). O yuvadakı səhifə "dirty"dirsə, əvvəlcə diskə yazılmalıdır, yalnız sonra yeni səhifə üçün boşaldılır — məhz buna görə Background Writer əvvəlcədən dirty page-ləri yazır, ki backend-lər bu məcburi yazma ilə qarşılaşıb ləngiməsin.

---

## 7. Xülasə cədvəli

| Proses | Nə vaxt aktivdir | Əsas vəzifə |
|---|---|---|
| Postmaster | həmişə | digər prosesləri idarə edir |
| Backend | hər bağlantı üçün | SQL icra edir |
| Autovacuum | arxa planda, davamlı | dead tuple təmizliyi, statistika |
| Background Writer | arxa planda, davamlı | dirty page-ləri tədricən yazır |
| WAL Writer | arxa planda, davamlı | WAL-ı diskə yazır |
| Checkpointer | müəyyən aralıqlarla | tam sinxronizasiya nöqtəsi qoyur |
| Stats Collector | arxa planda, davamlı | fəaliyyət statistikası toplayır |
| Logger | arxa planda, davamlı | log mesajlarını yazır |
| Archiver | `archive_mode=on` olanda | WAL fayllarını arxivləyir |
| WAL Sender/Receiver | replikasiya qurulanda | WAL-ı standby-a ötürür/qəbul edir |

---

*Bu fayl əsas kursla paralel oxunmaq üçündür — bir dəfəyə əzbərləmək lazım deyil. Faza 5 (VACUUM/performans), 7 (tranzaksiyalar/MVCC), 8-9 (administrasiya/replikasiya), 10 (internals) bu mövzulara təkrar-təkrar, hər dəfə bir az daha dərin qayıdacaq.*
