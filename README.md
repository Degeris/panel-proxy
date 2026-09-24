# 💙 Panel Proxy

<p align="center">
  <b>🔗 Hide your Backend behind your Domain</b><br>
  Simple • Fast • Lightweight
</p>

<p align="center">
  <a href="https://github.com/Degeris/panel-proxy">
    <img src="https://img.shields.io/badge/GitHub-Degeris%2Fpanel--proxy-black?style=for-the-badge&logo=github" alt="GitHub">
  </a>
</p>

---

## ⚡ نصب سریع

برای نصب مستقیم آخرین نسخه، دستور زیر را روی سرور اجرا کنید:

```bash
curl -fsSL -o install.sh https://raw.githubusercontent.com/Degeris/panel-proxy/main/install.sh && chmod +x install.sh && ./install.sh
```

این دستور:

- 📥 فایل `install.sh` را از GitHub دانلود می‌کند.
- ⚙️ دسترسی اجرای فایل را فعال می‌کند.
- 🚀 Installer را اجرا می‌کند.

---

## 📌 معرفی

**Panel Proxy** یک ابزار سبک و کاربردی برای قرار دادن آدرس اصلی **پنل، سرویس یا Backend** پشت یک دامنه و مسیر اختصاصی است.

اگر برای فروش یا ارائه‌ی **پنل ادمینی** یک آدرس اصلی دارید و می‌خواهید آدرس اصلی پنل را پشت دامنه‌ی خودتان قرار دهید، می‌توانید از Panel Proxy استفاده کنید.

به‌جای ارائه مستقیم آدرس اصلی Backend، می‌توانید یک آدرس اختصاصی روی دامنه خود ایجاد کنید.

### 💡 مثال

🔴 **آدرس اصلی:**

```text
https://server.example.com:2083/xxxxx
```

⬇️

🟢 **آدرس قابل ارائه به کاربر:**

```text
https://your-domain.com/Hcctdhjiffhdsehj
```

Panel Proxy درخواست‌های دریافتی از مسیر اختصاصی را به Backend اصلی هدایت می‌کند.

---

## ✨ امکانات

- 🔗 قرار دادن Backend پشت دامنه
- 🎲 ساخت مسیرهای تصادفی و اختصاصی
- 🔄 Reverse Proxy
- 🌐 پشتیبانی از Domain
- 📦 مناسب برای ارائه و فروش سرویس
- ⚡ نصب سریع و ساده
- 🖥️ مناسب برای سرورهای Linux
- 🔐 عدم استفاده از آدرس مستقیم Backend در URL عمومی

---

## 💡 کاربردها

Panel Proxy می‌تواند برای موارد مختلفی استفاده شود:

- 🛒 فروش و ارائه پنل‌های ادمینی
- ⚙️ پنل‌های مدیریتی
- 🌐 API و Backend
- ☁️ سرویس‌های آنلاین
- 📦 سرویس‌های اشتراکی
- 🔗 ایجاد URL اختصاصی برای کاربران
- 🖥️ قرار دادن سرویس‌های مختلف پشت یک Domain

---

## 🎯 چرا Panel Proxy؟

فرض کنید یک پنل ادمینی برای فروش یا ارائه سرویس دارید و آدرس اصلی آن روی یک سرور قرار دارد.

به‌جای اینکه آدرس اصلی را مستقیماً در اختیار کاربر قرار دهید، می‌توانید آن را پشت Domain خود قرار دهید:

```text
Original Backend
       │
       ▼
Panel Proxy
       │
       ▼
your-domain.com/RandomPath
       │
       ▼
      User
```

برای هر سرویس می‌توان یک مسیر اختصاصی ایجاد کرد، مانند:

```text
/Hcctdhjiffhdsehj
```

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

درخواست کاربر ابتدا به Domain ارسال می‌شود و Panel Proxy آن را به Backend تنظیم‌شده منتقل می‌کند.

---

## 🔗 نمونه

### Backend اصلی

```text
https://server.example.com:2083/xxxxx
```

### URL قابل ارائه

```text
https://your-domain.com/Hcctdhjiffhdsehj
```

کاربر از URL روی Domain استفاده می‌کند و Panel Proxy درخواست را به Backend اصلی ارسال می‌کند.

---

## 🛠️ نصب دستی

در صورت نیاز می‌توانید Repository را Clone کرده و Installer را اجرا کنید:

```bash
git clone https://github.com/Degeris/panel-proxy.git
cd panel-proxy
chmod +x install.sh
./install.sh
```

---

## 📦 نصب با یک دستور

اگر فقط می‌خواهید Installer را دانلود و اجرا کنید:

```bash
curl -fsSL -o install.sh https://raw.githubusercontent.com/Degeris/panel-proxy/main/install.sh && chmod +x install.sh && ./install.sh
```

---

## 🖥️ Requirements

- Linux Server
- دسترسی `root`
- Domain
- اتصال اینترنت
- تنظیم DNS دامنه به سمت سرور

---

## 🔐 نکات امنیتی

Panel Proxy باعث می‌شود آدرس Backend در **URL عمومی** استفاده نشود؛ اما این موضوع به‌تنهایی به معنی غیرقابل‌شناسایی یا غیرقابل‌دسترسی بودن Backend از روش‌های دیگر نیست.

برای امنیت بهتر:

- 🔒 دسترسی مستقیم Backend را محدود کنید.
- 🧱 Firewall مناسب تنظیم کنید.
- 🔑 Authentication مناسب داشته باشید.
- 🔐 از HTTPS استفاده کنید.
- 🚫 اطلاعات حساس را داخل Repository عمومی قرار ندهید.
- 🛡️ Secretها و تنظیمات خصوصی را در فایل‌های عمومی قرار ندهید.

---

## 🔗 Repository

**GitHub:**

https://github.com/Degeris/panel-proxy

---

## 📄 License

برای اطلاعات مربوط به License پروژه، فایل `LICENSE` را مشاهده کنید.

---

<p align="center">
  🚀 <b>Panel Proxy</b><br>
  <sub>Simple • Fast • Lightweight</sub>
</p>
