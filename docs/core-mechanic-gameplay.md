# Core Mechanic Gameplay — Balap Karung

> **Versi:** Core Prototype v0.1  
> **Platform:** Roblox, mobile first  
> **Referensi:** [MVP Game Design Document](./concept.md)  
> **Status:** Spesifikasi awal untuk implementasi dan playtest

---

## 1. Tujuan Prototype

Prototype ini harus membuktikan satu hal:

> Apakah kombinasi **auto movement + rhythm chain + peningkatan speed** terasa seru, kompetitif, dan membuat pemain ingin langsung mencoba lagi?

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
Karakter bergerak otomatis ke depan
    ↓
Reaction Window muncul
    ↓
Pemain menekan tombol atau melewatkannya
    ↓
Hasil: Perfect / Good / Miss
    ↓
Speed diperbarui
    ↓
Ulangi sampai melewati garis finish
```

Keputusan pemain hanya satu: **kapan menekan tombol**. Kedalaman gameplay datang dari akurasi timing dan kemampuan membangun speed sepanjang race.

---

## 3. Player Control

### Input utama

- Mobile: tap tombol besar di layar.
- PC: klik kiri atau `Space`.
- Gamepad: tombol utama, default `A` / `Cross`.

### Aturan kontrol

- Pemain tidak mengontrol arah dan tidak perlu menekan tombol untuk bergerak.
- Satu Reaction Window hanya menerima satu input yang valid.
- Input saat tidak ada Reaction Window tidak memberi efek gameplay.
- Menahan tombol tidak dihitung sebagai input berulang.
- Input tambahan setelah window selesai diabaikan agar spam tidak menguntungkan.

---

## 4. Auto Movement

Auto movement adalah sistem pergerakan dasar karakter menuju garis finish. Karakter tetap menyentuh tanah; tidak ada physics jump atau vertical velocity.

Visual gerakan balap karung atau "hop" akan dibuat melalui animation pada tahap berikutnya. Animation tidak menentukan posisi maupun hasil balapan.

### Aturan

- Karakter selalu mengikuti jalur race yang telah ditentukan.
- Pemain tidak dapat keluar jalur karena input gerak.
- Server hanya mengatur forward Speed karakter.
- Perfect dan Good tidak menghentikan movement.
- Miss menghentikan movement sekitar 0,65 detik sebagai recovery placeholder.
- Perubahan kecepatan harus dilakukan secara halus, bukan melonjak secara visual.
- Animation tidak boleh mengubah hasil simulasi balapan.

### Nilai awal untuk playtest

| Parameter | Nilai awal |
|---|---:|
| Kecepatan awal | 32 studs/detik |
| Kecepatan maksimum tier | 44 studs/detik |
| Recovery Miss | 0,65 detik |

Nilai ini adalah titik awal tuning, bukan angka final.

---

## 5. Reaction Window

Reaction Window adalah indikator statis yang muncul secara tiba-tiba. Pemain harus bereaksi dan menekan tombol sebelum indikator menghilang. Semakin cepat pemain merespons setelah indikator muncul, semakin baik hasilnya.

### Urutan satu rhythm chain

```text
Prompt muncul → Pemain tap → Jeda 0,35 detik → Prompt berikutnya / chain selesai
```

1. Indikator muncul pada posisi layar yang dipilih secara acak untuk setiap prompt.
2. Posisi dibatasi ke safe area mobile agar tombol tidak terpotong atau tertutup UI utama.
3. Indikator berbentuk lingkaran dengan icon placeholder, tanpa teks urutan atau timer.
4. Saat muncul, lingkaran melakukan scale pop lalu pulse selama window aktif.
5. Tombol tidak bergerak setelah muncul; posisi baru dipilih pada prompt berikutnya.
6. Pemain menekan tombol satu kali selama window aktif.
7. Setelah ditekan, lingkaran jatuh ke bawah layar dengan akselerasi, drift, dan rotasi seperti terkena gravitasi.
8. Sistem menghitung waktu reaksi sejak indikator muncul.
9. Hasil langsung ditampilkan dan memengaruhi Speed.
10. Setelah input berhasil, prompt berikutnya muncul setelah jeda 0,35 detik.
11. Satu chain berisi 1–3 prompt.
12. Jika pemain tidak menekan sampai window berakhir, hasilnya Miss dan chain langsung berhenti.

Animasi indikator hanya berfungsi sebagai feedback visual. Posisi dan animasinya tidak menentukan hasil gameplay.

### Nilai awal timing

| Hasil | Waktu reaksi sejak muncul | Efek |
|---|---:|---|
| Perfect | 0–400 ms | Speed 2× selama 3 detik; Streak +1; chain berlanjut |
| Good | Setelah 400 ms, sebelum window habis | Speed 1,5× selama 3 detik; Streak 0; chain berlanjut |
| Miss | Window habis / tidak menekan | Boost batal; Streak 0; Speed Tier turun; recovery; chain berhenti |

Catatan:

- Tidak ada penalti karena menekan terlalu cepat setelah indikator muncul.
- Input sebelum indikator aktif diabaikan dan tidak dapat disimpan untuk event berikutnya.
- Hasil dihitung dari waktu input terhadap waktu kemunculan indikator, bukan dari animasi visualnya.
- Durasi aktif Reaction Window mengikuti Speed Tier pemain.
- Perfect threshold tetap **400 ms** pada semua tier.

### Frekuensi event

- Rhythm Chain pertama muncul sekitar 2–4 detik setelah start.
- Jeda antar-chain dipilih secara acak antara **2,5–4 detik**.
- Panjang setiap chain dipilih secara acak antara **1–3 prompt**.
- Jeda antar-prompt dalam chain adalah **0,35 detik**.
- Chain tidak boleh muncul bertumpuk.
- Event terakhir tidak dibuat terlalu dekat dengan garis finish agar hasilnya tetap terbaca.

Randomisasi mencegah pemain sekadar menghafal pola. Posisi berubah pada setiap prompt, tetapi tetap dibatasi ke safe area layar.

---

## 6. Speed System

Speed adalah kecepatan maju karakter dalam studs per detik. Speed dibagi menjadi empat tier yang juga menentukan durasi Reaction Window.

### Perubahan Speed

- Semua pemain mulai pada tier Normal.
- Tiga Perfect berturut-turut menaikkan Speed satu tier.
- Perfect langsung memberi multiplier **2× selama 3 detik**.
- Good langsung memberi multiplier **1,5× selama 3 detik**.
- Good tidak mengubah tier, tetapi mengembalikan Perfect Streak ke 0.
- Miss menurunkan Speed satu tier, mengembalikan streak ke 0, dan menghentikan chain.
- Miss langsung membatalkan boost aktif.
- Speed tidak turun secara pasif.
- Miss pada tier Normal tidak menurunkan Speed lagi.

Perfect atau Good baru akan mengganti multiplier aktif dan mengulang durasinya dari 3 detik.

| Tier | Speed | Durasi prompt |
|---|---:|---:|
| Normal | 32 studs/detik | 1,20 detik |
| Fast | 36 studs/detik | 0,95 detik |
| Rush | 40 studs/detik | 0,75 detik |
| On Fire | 44 studs/detik | 0,60 detik |

Semakin cepat pemain, semakin singkat kesempatan untuk menghindari Miss. Ketika pemain melakukan Miss, tier turun sehingga prompt berikutnya otomatis menjadi lebih mudah.

---

## 7. Feedback Gameplay

Setiap input harus menghasilkan feedback dalam waktu secepat mungkin.

### Perfect

- Teks `PERFECT!` dengan warna paling menonjol.
- Speed dan walk animation langsung menjadi 2× selama 3 detik.
- Bunyi tajam dan memuaskan.
- Flash/ring singkat pada Reaction Window.
- Burst debu atau trail pada karakter.
- Kamera memberi dorongan ringan, tanpa mengganggu visibilitas.

### Good

- Teks `GOOD`.
- Speed dan walk animation langsung menjadi 1,5× selama 3 detik.
- Bunyi feedback yang lebih ringan.
- Efek visual kecil.

### Miss

- Teks `MISS`.
- Bunyi gagal yang singkat.
- Speed bar turun dengan jelas.
- Movement berhenti selama sekitar **0,65 detik**.
- Untuk prototype, movement dan walk animation berhenti selama recovery tanpa memanipulasi pose karakter.
- Visual tersungkur akan ditambahkan memakai fall animation khusus, bukan physics atau tween root.
- Setelah itu karakter langsung kembali bergerak.
- Miss tidak mengeluarkan pemain dari race dan tidak memberi stun panjang.

### Prinsip feedback

- UI, audio, animasi, dan perubahan speed harus menyampaikan hasil yang sama.
- Feedback tidak boleh menutupi Reaction Window berikutnya.
- Camera shake harus sangat ringan dan dapat dikurangi lewat pengaturan aksesibilitas.
- Hasil tidak boleh bergantung pada warna saja; gunakan teks, bentuk, dan suara.

### Character animation prototype

- Idle: `rbxassetid://92750155061995`
- Walk/hop visual: `rbxassetid://73682520851433`
- Fall/Miss: `rbxassetid://105372185107291`
- Walk animation memakai playback `2×` pada base Speed 32 dan terus mengikuti effective Speed hingga maksimal playback `4×`.
- Ketika Miss, idle/walk berhenti dan fall animation non-looping dimainkan dengan priority Action.
- Animation hanya presentasi; server tetap menentukan movement dan hasil race.

### Sound prototype

- `hop`: diputar oleh animation marker `OnHop` pada walk/hop animation.
- `good`: diputar ketika server memberi verdict Good.
- `perfect`: diputar ketika server memberi verdict Perfect.
- `miss`: diputar ketika server memberi verdict Miss.
- Sound ID dan volume diatur terpusat melalui `GameConfig.sounds`.
- Sound ID dibiarkan kosong sampai asset final dipilih.

---

## 8. Race Rules

### Start

- Semua pemain ditempatkan di garis start.
- Sebelum race, pemain menunggu selama 30 detik di lobby.
- Track berikutnya dipilih secara acak tanpa pengulangan langsung dan sudah di-clone ke
  `Workspace.ActiveTrack` selama waktu tunggu lobby.
- Timer lobby menggunakan `StarterGui.Timer.Frame.LocationTile.Bottom.Countdown`.
- Setelah masuk lane, `RaceTimer` menjalankan countdown 10 detik: `Bersedia`, `Siap`, lalu
  `Mulai!`. Pergerakan tetap terkunci sampai `Mulai!` selesai ditampilkan.
- Semua pemain mulai dengan Speed yang sama, yaitu 32 studs/detik.

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
3. Speed saat finish.

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

| State | Auto movement | Input timing | Perubahan Speed |
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

- Server menjadi sumber kebenaran untuk state race, Speed, progress, dan hasil finish.
- Client menangani UI, animasi, audio, dan mengirim waktu input ke server.
- Server memvalidasi bahwa input terjadi pada Reaction Window yang aktif dan belum pernah dipakai.
- Input rate dibatasi untuk mencegah spam atau exploit.
- Toleransi latency perlu diterapkan secara terbatas berdasarkan timing window yang server kirim ke client.
- Client tidak boleh menentukan sendiri hasil Perfect, perubahan Speed, atau posisi akhir.

Prototype lokal boleh dibuat lebih dahulu, tetapi struktur sistem harus tetap memungkinkan validasi server tanpa menulis ulang seluruh mechanic.

---

## 11. Scope Implementasi Core

### Wajib ada

- Satu jalur race lurus atau spline sederhana.
- Auto movement di tanah dari start sampai finish.
- Satu input lintas mobile, PC, dan gamepad.
- Reaction Window dengan Perfect, Good, dan Miss.
- Empat Speed Tier dan durasi prompt per tier.
- Rhythm Chain berisi 1–3 prompt.
- Speed bar, Perfect Streak, jarak tersisa, dan feedback hasil.
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
- [ ] Karakter bergerak di tanah tanpa physics jump.
- [ ] Setiap Reaction Window hanya menghasilkan satu verdict.
- [ ] Posisi indikator berubah pada setiap prompt dan tetap berada di safe area.
- [ ] Indikator hanya menampilkan lingkaran dan `ImageLabel` icon placeholder.
- [ ] Indikator melakukan pop, pulse, lalu jatuh natural ketika ditekan.
- [ ] Perfect, Good, dan Miss sesuai dengan waktu reaksi yang ditentukan.
- [ ] Tidak menekan tombol menghasilkan Miss.
- [ ] Spam atau menahan tombol tidak memberi keuntungan.
- [ ] Tiga Perfect beruntun menaikkan satu Speed Tier.
- [ ] Good mereset streak tanpa mengubah Speed Tier.
- [ ] Miss menurunkan satu Speed Tier dan menghentikan chain.
- [ ] Durasi prompt semakin pendek pada Speed Tier yang lebih tinggi.
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
- Speed rata-rata dan tertinggi.
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
2. Implementasikan forward movement di tanah pada base Speed.
3. Tambahkan Reaction Window dan verdict timing.
4. Tambahkan Rhythm Chain, Perfect Streak, dan Speed Tier.
5. Tambahkan UI dan feedback dasar.
6. Pindahkan validasi penting ke server dan uji dengan dua pemain.
7. Lakukan playtest dan tuning angka.
8. Setelah core terasa seru, baru tambahkan obstacle dan variasi map.

---

## 15. Open Questions untuk Playtest

Hal berikut tidak perlu diputuskan sebelum prototype pertama, tetapi harus dijawab melalui playtest:

- Apakah tiga Perfect per kenaikan tier terasa terlalu cepat atau terlalu lambat?
- Apakah chain sepanjang 1–3 prompt cukup bervariasi?
- Apakah durasi prompt 1,20–0,60 detik masih terasa adil?
- Apakah semua pemain harus mendapat jadwal event yang identik?
- Seberapa besar efek latency compensation yang masih terasa adil?
- Apakah pemain yang tertinggal membutuhkan comeback mechanic, atau performa timing saja sudah cukup?

Keputusan final harus berdasarkan rasa bermain dan data, bukan hanya angka di dokumen.
