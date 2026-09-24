# 💙 Panel Proxy

<p align="center">
  <b>🔗 Panel Proxy — Hide Your Backend Behind Your Domain</b><br>
  Simple • Fast • Lightweight
</p>

---

## ⚡ نصب سریع

برای نصب خودکار Panel Proxy روی سرور، فقط دستور زیر را اجرا کنید:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Degeris/panel-proxy/main/Degeris.sh)
```

اسکریپت `Degeris.sh` به‌صورت خودکار پیش‌نیازهای موردنیاز را نصب کرده و سپس `install.sh` اصلی پروژه را دانلود و اجرا می‌کند.

---

## 📌 معرفی

**Panel Proxy** یک ابزار سبک برای قرار دادن آدرس اصلی **پنل، سرویس یا Backend** پشت یک دامنه و مسیر اختصاصی است.

اگر برای فروش یا ارائه‌ی **پنل ادمینی** یک آدرس اصلی دارید و نمی‌خواهید آدرس مستقیم Backend را در اختیار کاربران قرار دهید، می‌توانید آن را پشت Domain خود قرار دهید.

### 🔗 مثال

🔴 آدرس اصلی:

```text
https://server.example.com:2083/xxxxx
```

⬇️

🟢 آدرس قابل ارائه به کاربر:

```text
https://your-domain.com/Hcctdhjiffhdsehj
```

کاربر از طریق Domain و مسیر اختصاصی به سرویس متصل می‌شود و Panel Proxy درخواست را به Backend اصلی منتقل می‌کند.

---

## ✨ امکانات

- 🔗 قرار دادن Backend پشت Domain
- 🎲 ساخت مسیرهای تصادفی و اختصاصی
- 🔄 Reverse Proxy
- 🌐 پشتیبانی از Custom Domain
- 📦 مناسب برای ارائه و فروش سرویس
- ⚡ نصب سریع و خودکار
- 🖥️ مناسب برای Linux Server
- 🔐 عدم نمایش آدرس مستقیم Backend در URL عمومی
- 🛠️ نصب خودکار پیش‌نیازها

---

## 💡 کاربردها

Panel Proxy می‌تواند برای موارد مختلفی استفاده شود:

- 🛒 فروش و ارائه پنل‌های ادمینی
- ⚙️ پنل‌های مدیریتی
- 🌐 API و Backend
- ☁️ سرویس‌های آنلاین
- 📦 سرویس‌های اشتراکی
- 🔗 ایجاد URL اختصاصی برای کاربران
- 🖥️ قرار دادن سرویس‌ها پشت یک Domain

---

## 🎯 نمونه استفاده

فرض کنید آدرس اصلی پنل شما این باشد:

```text
https://server.example.com:2083/
```

به‌جای ارائه مستقیم این آدرس، می‌توانید آن را پشت دامنه خود قرار دهید:

```text
https://your-domain.com/Hcctdhjiffhdsehj
```

در این حالت کاربر از آدرس Domain استفاده می‌کند و درخواست از طریق Panel Proxy به Backend اصلی منتقل می‌شود.

---

## ⚙️ نحوه عملکرد

```text
                    👤 User
                       │
                       ▼
              🌐 your-domain.com
                       │
                       ▼
             🔐 /RandomPath
                       │
                       ▼
                🚀 Panel Proxy
                       │
                       ▼
              🖥️ Original Backend
```

Panel Proxy درخواست دریافتی از مسیر اختصاصی را به Backend تنظیم‌شده ارسال می‌کند.

---

## 📥 نصب‌کننده Degeris

فایل `Degeris.sh` برای ساده‌تر شدن نصب پروژه ساخته شده است.

این فایل مراحل زیر را انجام می‌دهد:

```text
1. بررسی دسترسی Root
        ↓
2. شناسایی Ubuntu / Debian
        ↓
3. به‌روزرسانی Package List
        ↓
4. نصب پیش‌نیازها
        ↓
5. نصب و راه‌اندازی Nginx
        ↓
6. دانلود install.sh
        ↓
7. اجرای install.sh
        ↓
8. تکمیل نصب Panel Proxy
```

### 📦 پیش‌نیازهای نصب‌شده

در فرآیند نصب، ابزارهای موردنیاز عمومی مانند موارد زیر نصب می‌شوند:

```text
nginx
curl
wget
git
ca-certificates
openssl
unzip
tar
sudo
socat
lsof
net-tools
```

---

## 🛠️ نصب دستی

اگر می‌خواهید Repository را به‌صورت دستی دریافت کنید:

```bash
git clone https://github.com/Degeris/panel-proxy.git
cd panel-proxy
chmod +x install.sh
./install.sh
```

---

## 🌐 نیازمندی‌ها

قبل از استفاده توصیه می‌شود موارد زیر را داشته باشید:

- 🖥️ Linux Server
- 🔑 دسترسی Root
- 🌐 یک Domain
- 📡 اتصال اینترنت
- ⚙️ امکان تنظیم DNS دامنه به سمت Server

---

## 🔐 نکات امنیتی

Panel Proxy باعث می‌شود آدرس Backend در **URL عمومی** استفاده نشود؛ اما این موضوع به‌تنهایی به معنی غیرقابل‌شناسایی یا غیرقابل‌دسترسی بودن Backend از روش‌های دیگر نیست.

برای امنیت بیشتر:

- 🔒 دسترسی مستقیم Backend را محدود کنید.
- 🧱 Firewall مناسب تنظیم کنید.
- 🔑 Authentication مناسب داشته باشید.
- 🔐 از HTTPS استفاده کنید.
- 🚫 اطلاعات حساس را داخل Repository عمومی قرار ندهید.
- 🛡️ Secretها و Configurationهای خصوصی را عمومی نکنید.

---

## 📂 ساختار Repository

```text
panel-proxy/
│
├── install.sh
├── Degeris.sh
├── README.md
└── LICENSE
```

---

## 🔗 GitHub

Repository رسمی پروژه:

https://github.com/Degeris/panel-proxy

---

## 📄 License

برای مشاهده شرایط استفاده و License پروژه، فایل `LICENSE` را بررسی کنید.

---

<p align="center">
  🚀 <b>Panel Proxy</b><br>
  <sub>Simple • Fast • Lightweight</sub>
</p>
