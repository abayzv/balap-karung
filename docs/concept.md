# 🥔 Balap Karung - MVP Game Design Document

> **Versi:** MVP v0.1  
> **Target Rilis:** Event Agustusan  
> **Platform:** Roblox (Mobile First)

---

# 1. Core Vision

Balap Karung bukan game obby.

Balap Karung adalah **reaction racing game**, dimana karakter bergerak otomatis dan pemain harus bereaksi terhadap berbagai action window untuk menjaga momentum dan menjadi yang tercepat mencapai garis finish.

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

Karakter akan otomatis melakukan hop (lompat menggunakan karung).

Player hanya melakukan action ketika muncul **Reaction Window**.

Contoh:

```
Auto Hop

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

## Auto Hop

Karakter otomatis melompat.

Misalnya setiap:

- 0.8 detik

Player tidak perlu spam tombol.

---

## Reaction Window

Sesekali muncul Action Window.

Contoh:

```
      ⚡

 TAP
```

Player harus menekan tombol saat timing yang tepat.

Hasilnya:

### Perfect

- Momentum bertambah
- Speed meningkat
- Animasi lebih smooth
- Efek visual muncul

### Good

- Tidak berubah

### Miss

- Momentum berkurang
- Sedikit kehilangan kecepatan

---

# 5. Momentum System

Momentum menentukan kecepatan balapan.

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

Semakin tinggi Momentum:

- Hop lebih cepat
- Speed meningkat
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

- Momentum cepat turun
- Window muncul lebih cepat

---

## Batu

Efek:

- Area Perfect lebih kecil

---

## Jalan Menanjak

Efek:

- Momentum cepat habis

---

## Jalan Menurun

Efek:

- Momentum bertambah
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

      [ TAP ]

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

- Auto Hop
- Reaction Window
- Momentum
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