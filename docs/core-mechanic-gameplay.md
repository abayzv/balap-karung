# Core Mechanic Gameplay — Balap Karung

> **Versi:** Core Prototype v0.1  
> **Platform:** Roblox, mobile first  
> **Referensi:** [MVP Game Design Document](./concept.md)  
> **Status:** Spesifikasi awal untuk implementasi dan playtest

---

## 1. Tujuan Prototype

Prototype ini harus membuktikan satu hal:

> Apakah kombinasi **auto-hop + reaction timing + momentum** terasa seru, kompetitif, dan membuat pemain ingin langsung mencoba lagi?

Fokus tahap ini hanya pengalaman selama balapan. Lobby, map voting, reward, shop, quest, dan variasi obstacle belum menjadi prioritas.

### Target pengalaman

- Mudah dipahami hanya dengan satu tombol.
- Pemain tetap aktif walaupun karakter bergerak otomatis.
- Perfect terasa memuaskan dan memberi keuntungan yang terlihat.
- Miss terasa merugikan, tetapi tidak langsung menghancurkan peluang menang.
- Pemain yang konsisten lebih cepat daripada pemain yang sekadar beruntung.
- Satu race selesai dalam sekitar **45–60 detik**.

---

## 2. Core Gameplay Loop

```text
Race dimulai
    ↓
Karakter auto-hop ke depan
    ↓
Reaction Window muncul
    ↓
Pemain menekan tombol atau melewatkannya
    ↓
Hasil: Perfect / Good / Miss
    ↓
Momentum dan kecepatan diperbarui
    ↓
Ulangi sampai melewati garis finish
```

Keputusan pemain hanya satu: **kapan menekan tombol**. Kedalaman gameplay datang dari akurasi timing dan kemampuan menjaga momentum sepanjang race.

---

## 3. Player Control

### Input utama

- Mobile: tap tombol besar di layar.
- PC: klik kiri atau `Space`.
- Gamepad: tombol utama, default `A` / `Cross`.

### Aturan kontrol

- Pemain tidak mengontrol arah dan tidak perlu menekan tombol untuk hop biasa.
- Satu Reaction Window hanya menerima satu input yang valid.
- Input saat tidak ada Reaction Window tidak memberi efek gameplay.
- Menahan tombol tidak dihitung sebagai input berulang.
- Input tambahan setelah window selesai diabaikan agar spam tidak menguntungkan.

---

## 4. Auto-Hop

Auto-hop adalah sistem pergerakan dasar karakter menuju garis finish.

### Siklus hop

1. Karakter melakukan take-off.
2. Karakter bergerak maju selama di udara.
3. Karakter mendarat.
4. Setelah jeda singkat, hop berikutnya dimulai otomatis.

### Aturan

- Karakter selalu mengikuti jalur race yang telah ditentukan.
- Pemain tidak dapat keluar jalur karena input gerak.
- Jarak dan frekuensi hop dipengaruhi oleh Momentum.
- Perubahan kecepatan harus dilakukan secara halus, bukan melonjak secara visual.
- Animasi tidak boleh mengubah hasil simulasi balapan; gameplay ditentukan oleh sistem movement.

### Nilai awal untuk playtest

| Parameter | Nilai awal |
|---|---:|
| Interval hop pada Momentum 0 | 0,90 detik |
| Interval hop pada Momentum 100 | 0,65 detik |
| Kecepatan minimum | 12 studs/detik |
| Kecepatan maksimum | 20 studs/detik |
| Momentum awal | 30 |

Nilai ini adalah titik awal tuning, bukan angka final.

---

## 5. Reaction Window

Reaction Window adalah indikator statis yang muncul secara tiba-tiba. Pemain harus bereaksi dan menekan tombol sebelum indikator menghilang. Semakin cepat pemain merespons setelah indikator muncul, semakin baik hasilnya.

### Urutan satu event

```text
Indikator muncul → Window aktif → Pemain tap / waktu habis → Indikator menghilang → Feedback hasil
```

1. Indikator muncul langsung pada posisi yang tetap.
2. Indikator boleh memakai animasi ringan seperti fade-in, scale pop, glow, atau pulse.
3. Indikator tidak bergeser, berputar mengelilingi target, atau memakai bar yang bergerak.
4. Pemain menekan tombol satu kali selama window aktif.
5. Sistem menghitung waktu reaksi sejak indikator muncul.
6. Hasil langsung ditampilkan dan memengaruhi Momentum.
7. Setelah menerima input atau durasinya habis, indikator menghilang dengan fade-out singkat.
8. Jika pemain tidak menekan sampai window berakhir, hasilnya Miss.

Animasi indikator hanya berfungsi sebagai feedback visual. Posisi dan animasinya tidak menentukan hasil gameplay.

### Nilai awal timing

| Hasil | Waktu reaksi sejak muncul | Efek Momentum |
|---|---:|---:|
| Perfect | 0–400 ms | +15 |
| Good | 401–1.500 ms | +3 |
| Miss | lebih dari 1.500 ms / tidak menekan | -18 |

Catatan:

- Tidak ada penalti karena menekan terlalu cepat setelah indikator muncul.
- Input sebelum indikator aktif diabaikan dan tidak dapat disimpan untuk event berikutnya.
- Hasil dihitung dari waktu input terhadap waktu kemunculan indikator, bukan dari animasi visualnya.
- Durasi aktif awal Reaction Window adalah **1,5 detik**.
- Nilai Momentum selalu dibatasi antara `0–100`.

### Frekuensi event

- Reaction Window pertama muncul setelah pemain memahami ritme auto-hop, sekitar 2–3 detik setelah start.
- Jeda awal antar-event dipilih secara acak antara **2,5–4 detik**.
- Event tidak boleh muncul bertumpuk.
- Harus ada jeda aman minimal **1,5 detik** setelah sebuah event selesai.
- Event terakhir tidak dibuat terlalu dekat dengan garis finish agar hasilnya tetap terbaca.

Randomisasi mencegah pemain sekadar menghafal pola. Indikator harus selalu muncul di area layar yang konsisten agar pemain dapat fokus pada reaksi, bukan mencari posisi UI.

---

## 6. Momentum System

Momentum adalah nilai `0–100` yang menggambarkan performa pemain selama race. Momentum secara langsung menentukan kecepatan maju dan ritme hop.

### Perubahan Momentum

- Perfect menambah Momentum secara signifikan.
- Good mempertahankan ritme dan memberi tambahan kecil.
- Miss mengurangi Momentum, tetapi karakter tetap bergerak.
- Momentum turun secara pasif selama race agar pemain harus terus menjaga performa.

### Nilai awal decay

```text
Passive Decay = 2 Momentum per detik
```

Decay berhenti ketika race selesai.

### Konversi ke kecepatan

Gunakan interpolasi linear sebagai versi awal:

```text
Speed = MinSpeed + (Momentum / 100) × (MaxSpeed - MinSpeed)
```

Dengan nilai awal:

```text
Speed = 12 + (Momentum / 100) × 8
```

Contoh:

| Momentum | Kecepatan |
|---:|---:|
| 0 | 12 studs/detik |
| 25 | 14 studs/detik |
| 50 | 16 studs/detik |
| 75 | 18 studs/detik |
| 100 | 20 studs/detik |

### Momentum state

| State | Range | Presentasi |
|---|---:|---|
| Low | 0–24 | Hop berat, efek minimal |
| Normal | 25–59 | Gerakan standar |
| Fast | 60–84 | Debu lebih kuat, kamera sedikit melebar |
| On Fire | 85–100 | Trail/efek khusus dan rasa kecepatan maksimum |

State hanya mengubah presentasi. Kecepatan tetap mengikuti nilai Momentum secara kontinu agar transisinya halus.

---

## 7. Feedback Gameplay

Setiap input harus menghasilkan feedback dalam waktu secepat mungkin.

### Perfect

- Teks `PERFECT!` dengan warna paling menonjol.
- Bunyi tajam dan memuaskan.
- Flash/ring singkat pada Reaction Window.
- Burst debu atau trail pada karakter.
- Kamera memberi dorongan ringan, tanpa mengganggu visibilitas.

### Good

- Teks `GOOD`.
- Bunyi feedback yang lebih ringan.
- Efek visual kecil.

### Miss

- Teks `MISS`.
- Bunyi gagal yang singkat.
- Momentum bar turun dengan jelas.
- Karakter sedikit oleng atau kehilangan tenaga, tetapi kontrol tidak dikunci.

### Prinsip feedback

- UI, audio, animasi, dan perubahan speed harus menyampaikan hasil yang sama.
- Feedback tidak boleh menutupi Reaction Window berikutnya.
- Camera shake harus sangat ringan dan dapat dikurangi lewat pengaturan aksesibilitas.
- Hasil tidak boleh bergantung pada warna saja; gunakan teks, bentuk, dan suara.

---

## 8. Race Rules

### Start

- Semua pemain ditempatkan di garis start.
- Countdown `3–2–1–GO` mengunci pergerakan sampai `GO`.
- Semua pemain mulai dengan Momentum yang sama, yaitu 30.

### Selama race

- Setiap pemain menerima rangkaian Reaction Window dengan tingkat kesulitan yang setara.
- Urutan waktu event boleh berbeda sedikit, tetapi jumlah kesempatan dan rentang timing harus adil.
- Posisi pemain ditentukan dari progress sepanjang jalur, bukan jarak lurus ke finish.

### Finish

- Pemain finish ketika progress melewati garis finish.
- Waktu finish ditentukan oleh server.
- Setelah finish, movement dan Reaction Window pemain dihentikan.
- Untuk prototype, race berakhir ketika semua pemain finish atau batas waktu tercapai.

### Tie breaker

Jika dua pemain tercatat finish pada frame/server tick yang sama, urutan ditentukan oleh:

1. Waktu finish dengan presisi tertinggi yang tersedia.
2. Progress melewati garis finish pada tick tersebut.
3. Momentum saat finish.

---

## 9. Gameplay State

```text
Waiting
  ↓
Countdown
  ↓
Racing
  ↓
Finished
  ↓
Results
```

| State | Auto-hop | Input timing | Momentum decay |
|---|---:|---:|---:|
| Waiting | Tidak | Tidak | Tidak |
| Countdown | Tidak | Tidak | Tidak |
| Racing | Ya | Ya | Ya |
| Finished | Tidak | Tidak | Tidak |
| Results | Tidak | Tidak | Tidak |

State harus menjadi sumber kebenaran agar input atau movement tidak tetap aktif setelah race selesai.

---

## 10. Multiplayer dan Fairness

Untuk menjaga kompetisi tetap adil:

- Server menjadi sumber kebenaran untuk state race, Momentum, progress, dan hasil finish.
- Client menangani UI, animasi, audio, dan mengirim waktu input ke server.
- Server memvalidasi bahwa input terjadi pada Reaction Window yang aktif dan belum pernah dipakai.
- Input rate dibatasi untuk mencegah spam atau exploit.
- Toleransi latency perlu diterapkan secara terbatas berdasarkan timing window yang server kirim ke client.
- Client tidak boleh menentukan sendiri hasil Perfect, perubahan Momentum, atau posisi akhir.

Prototype lokal boleh dibuat lebih dahulu, tetapi struktur sistem harus tetap memungkinkan validasi server tanpa menulis ulang seluruh mechanic.

---

## 11. Scope Implementasi Core

### Wajib ada

- Satu jalur race lurus atau spline sederhana.
- Auto-hop dari start sampai finish.
- Satu input lintas mobile, PC, dan gamepad.
- Reaction Window dengan Perfect, Good, dan Miss.
- Momentum `0–100`, passive decay, dan pengaruhnya terhadap speed.
- Momentum bar, jarak tersisa, dan feedback hasil.
- Countdown, finish detection, waktu finish, dan urutan pemain.
- Minimal dua pemain untuk menguji rasa kompetitif.

### Belum dikerjakan

- Obstacle dan modifier track.
- Random event seperti ayam.
- Tiga map final.
- Lobby dan map voting.
- Reward, coin, shop, skin, trail, dan emote.
- Quest dan event Agustusan.
- Podium final dan flow Play Again yang lengkap.

---

## 12. Acceptance Criteria

Core mechanic dinyatakan siap masuk tahap berikutnya jika:

- [ ] Pemain dapat menyelesaikan race tanpa input gerak manual.
- [ ] Auto-hop tetap stabil pada seluruh range Momentum.
- [ ] Setiap Reaction Window hanya menghasilkan satu verdict.
- [ ] Indikator tetap pada satu posisi dan hanya memakai animasi visual ringan.
- [ ] Perfect, Good, dan Miss sesuai dengan waktu reaksi yang ditentukan.
- [ ] Tidak menekan tombol menghasilkan Miss.
- [ ] Spam atau menahan tombol tidak memberi keuntungan.
- [ ] Momentum tidak pernah kurang dari 0 atau lebih dari 100.
- [ ] Perubahan Momentum menghasilkan perubahan speed yang terasa dan halus.
- [ ] Dua pemain dengan performa timing berbeda menghasilkan posisi race yang berbeda secara konsisten.
- [ ] Server menentukan hasil mechanic dan finish secara konsisten.
- [ ] UI dapat dimainkan dengan nyaman pada layar mobile.
- [ ] Mayoritas race playtest selesai dalam 45–60 detik.
- [ ] Pemain baru memahami aksi utama tanpa penjelasan panjang.
- [ ] Setelah beberapa race, pemain dapat menjelaskan mengapa mereka menang atau kalah.

---

## 13. Data yang Dicatat Saat Playtest

Catat data berikut untuk setiap race:

- Durasi race.
- Jumlah Reaction Window.
- Jumlah dan persentase Perfect, Good, dan Miss.
- Momentum rata-rata dan tertinggi.
- Selisih waktu antara posisi pertama dan terakhir.
- Jumlah input di luar window.
- Platform dan perkiraan latency pemain.
- Apakah pemain ingin langsung bermain lagi.

### Pertanyaan playtest

1. Apakah pemain langsung memahami kapan harus menekan tombol?
2. Apakah Perfect terasa jauh lebih memuaskan daripada Good?
3. Apakah Miss terasa adil?
4. Apakah perubahan speed mudah dirasakan?
5. Apakah pemain merasa hasil race ditentukan oleh skill?
6. Apakah race terasa terlalu singkat, terlalu panjang, atau pas?

---

## 14. Urutan Pengerjaan

1. Buat jalur, progress tracking, start, dan finish.
2. Implementasikan movement auto-hop tanpa Momentum.
3. Tambahkan Reaction Window dan verdict timing.
4. Tambahkan Momentum dan hubungkan ke speed serta interval hop.
5. Tambahkan UI dan feedback dasar.
6. Pindahkan validasi penting ke server dan uji dengan dua pemain.
7. Lakukan playtest dan tuning angka.
8. Setelah core terasa seru, baru tambahkan obstacle dan variasi map.

---

## 15. Open Questions untuk Playtest

Hal berikut tidak perlu diputuskan sebelum prototype pertama, tetapi harus dijawab melalui playtest:

- Apakah Good sebaiknya memberi sedikit Momentum atau benar-benar netral?
- Apakah passive decay sebesar 2 per detik terlalu agresif?
- Apakah durasi Reaction Window perlu menjadi lebih singkat saat Momentum tinggi?
- Apakah semua pemain harus mendapat jadwal event yang identik?
- Seberapa besar efek latency compensation yang masih terasa adil?
- Apakah pemain yang tertinggal membutuhkan comeback mechanic, atau performa timing saja sudah cukup?

Keputusan final harus berdasarkan rasa bermain dan data, bukan hanya angka di dokumen.
