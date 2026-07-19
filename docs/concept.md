# 🥔 Balap Karung - MVP Game Design Document

> **Versi:** MVP v0.1  
> **Target Rilis:** Event Agustusan  
> **Platform:** Roblox (Mobile First)

---

# 1. Core Vision

Balap Karung bukan game obby.

Balap Karung adalah **reaction racing game**, dimana karakter bergerak otomatis dan pemain harus bereaksi terhadap berbagai action window untuk meningkatkan speed dan menjadi yang tercepat mencapai garis finish.

Inspirasi gameplay:

- Blade Ball (quick game loop)
- Dead by Daylight Skill Check (reaction mechanic)
- Rhythm Game (timing)

Namun gameplay tetap memiliki identitas sendiri.

---

# 2. Core Gameplay Loop

```text
Lobby
    ↓
Waiting Player
    ↓
Vote Map
    ↓
Countdown
    ↓
Race
    ↓
Reward
    ↓
Back to Lobby
```

Durasi satu match:

- 45 - 60 detik

---

# 3. Player Controls

Player **tidak mengontrol pergerakan karakter secara langsung.**

Karakter bergerak otomatis di tanah. Gerakan hop balap karung dibuat melalui animation, bukan physics jump.

Player hanya melakukan action ketika muncul **Reaction Window**.

Contoh:

```
Auto Movement

Hop
Hop
Hop

⚡

Tap!

Hop
Hop
```

---

# 4. Core Mechanic

## Auto Movement

Karakter otomatis bergerak maju sesuai Speed Tier. Tidak ada vertical movement dari gameplay code.

Player tidak perlu spam tombol.

---

## Reaction Window

Sesekali muncul Action Window.

Contoh:

```
      ⚡

  ★
```

Player harus menekan tombol saat timing yang tepat.

Hasilnya:

### Perfect

- Perfect Streak bertambah
- Tiga Perfect beruntun menaikkan Speed Tier
- Speed menjadi 2× selama 3 detik
- Animasi lebih smooth
- Efek visual muncul

### Good

- Speed Tier tetap
- Perfect Streak kembali ke 0
- Speed menjadi 1,5× selama 3 detik

### Miss

- Speed berkurang
- Boost aktif dibatalkan
- Rhythm Chain langsung berhenti
- Movement berhenti singkat; visual jatuh menunggu animation khusus

---

# 5. Speed System

Speed adalah kecepatan maju karakter dan ditampilkan langsung kepada pemain.

Speed menggunakan empat tier: Normal, Fast, Rush, dan On Fire. Semakin tinggi tier, karakter semakin cepat tetapi Reaction Window semakin singkat.

Setiap prompt muncul pada posisi layar yang acak. Perfect dan Good memberi multiplier Speed sementara agar dampak input langsung terlihat.

Prompt hanya menampilkan lingkaran dengan `ImageLabel` icon. Lingkaran melakukan pop dan pulse ketika muncul, lalu jatuh ke bawah layar secara natural setelah ditekan.

Sound hop disinkronkan melalui animation marker `OnHop`. Good, Perfect, dan Miss memiliki sound feedback masing-masing.

Contoh:

```
██████████
```

Perfect

↓

```
██████████████
```

Miss

↓

```
███████
```

Semakin tinggi Speed Tier:

- Speed meningkat
- Tombol lebih cepat menghilang
- Efek debu bertambah
- Kamera sedikit zoom out
- Terasa "On Fire"

---

# 6. Race Flow

Contoh jalannya pertandingan:

```
START

↓

Hop

↓

⚡

Perfect

↓

Hop

↓

Hop

↓

⚡

Miss

↓

Lawan menyalip

↓

⚡

Perfect

↓

Finish
```

---

# 7. Track Design

Track tidak menggunakan obstacle parkour.

Obstacle hanya mempengaruhi reaction.

---

## Map 1

Lapangan Desa

```
Start

↓

Rumput

↓

Kubangan

↓

Jalan Tanah

↓

Finish
```

---

## Map 2

Sawah

```
Start

↓

Pematang

↓

Lumpur

↓

Jembatan Bambu

↓

Finish
```

---

## Map 3

Komplek

```
Start

↓

Gang

↓

Motor Parkir

↓

Ayam

↓

Finish
```

---

# 8. Obstacle

## Lumpur

Efek:

- Speed cepat turun
- Window muncul lebih cepat

---

## Batu

Efek:

- Area Perfect lebih kecil

---

## Jalan Menanjak

Efek:

- Speed turun selama menanjak

---

## Jalan Menurun

Efek:

- Speed bertambah
- Namun Miss akan lebih berbahaya

---

## Ayam

Random Event.

Jika terkena:

- Knockback kecil
- Animasi lucu

---

# 9. UI

```
---------------------------------

🏁 Remaining : 24 m

███████████

        😀

       ⚡

       ( ★ )

---------------------------------
```

UI dibuat seminimal mungkin.

---

# 10. Match Reward

Juara 1

100 Coin

Juara 2

70 Coin

Juara 3

50 Coin

Peserta lainnya

20 Coin

Semua pemain tetap mendapatkan reward.

---

# 11. Shop

## Sack

- Karung Goni
- Karung Batik
- Karung Merah Putih
- Karung Emas

---

## Trail

- Debu
- Confetti
- Daun

---

## Victory Emote

- Joget
- Hormat
- Ketawa

---

# 12. Event Agustus

Quest:

- Main 5 Match
- Menang 3 Match
- Perfect 50 Kali

Reward:

- Skin Merah Putih
- Trail Bendera
- Badge Event

---

# 13. MVP Scope

## Gameplay

- Auto Movement
- Reaction Window
- Speed
- Finish Line

---

## Multiplayer

- Lobby
- Matchmaking
- Countdown
- Podium

---

## Content

- 3 Map
- 5 Skin
- Coin
- Shop

---

# 14. Core Feeling

Game harus memberikan rasa:

- Mudah dimainkan
- Sulit dikuasai
- Cepat
- Kompetitif
- Lucu
- Nagih

Setiap pemain harus selalu berpikir:

> "Ah... tadi tinggal dikit lagi Perfect."

Lalu langsung menekan tombol **Play Again**.
