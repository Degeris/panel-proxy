# 🚀 Panel Proxy

<p align="center">
  <b>🔗 Hide your Backend behind your Domain</b><br>
  Simple • Fast • Lightweight
</p>

---

## ⚡ نصب سریع

برای نصب مستقیم آخرین نسخه، دستور زیر را روی سرور اجرا کنید:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Degeris/panel-proxy/main/install.sh)
```

---

## 📌 معرفی

**Panel Proxy** یک ابزار سبک و کاربردی برای قرار دادن آدرس اصلی **پنل، سرویس یا Backend** پشت یک دامنه و مسیر اختصاصی است.

اگر برای فروش یا ارائه‌ی **پنل ادمینی** یک آدرس اصلی دارید و نمی‌خواهید کاربران مستقیماً از آدرس اصلی استفاده کنند، می‌توانید آن را پشت دامنه‌ی خودتان قرار دهید.

### 💡 مثال

🔴 **آدرس اصلی Backend:**

```text
https://server.example.com:2083/xxxxx
```

⬇️ تبدیل به:

🟢 **آدرس قابل ارائه به کاربر:**

```text
https://your-domain.com/Hcctdhjiffhdsehj
```

کاربر از طریق دامنه و مسیر اختصاصی به سرویس متصل می‌شود و Panel Proxy درخواست را به Backend اصلی ارسال می‌کند.

---

## ✨ امکانات

| قابلیت | توضیحات |
|---|---|
| 🔗 Domain Proxy | قرار دادن Backend پشت دامنه |
| 🎲 Random Path | ساخت مسیرهای تصادفی و اختصاصی |
| 🔄 Reverse Proxy | انتقال درخواست‌ها به Backend |
| 🌐 Custom Domain | استفاده از دامنه اختصاصی |
| 📦 Multi Service | مناسب برای مدیریت چند سرویس |
| ⚡ Fast Install | نصب سریع با یک دستور |
| 🖥️ Linux | مناسب برای سرورهای Linux |

---

## 💡 کاربردها

Panel Proxy می‌تواند برای موارد مختلفی استفاده شود:

- 🛒 فروش و ارائه پنل‌های ادمینی
- ⚙️ پنل‌های مدیریتی
- 🌐 API و Backend
- ☁️ سرویس‌های آنلاین
- 📦 سرویس‌های اشتراکی
- 🔗 ایجاد URL اختصاصی برای کاربران

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

Panel Proxy درخواست دریافت‌شده از مسیر اختصاصی را به Backend تنظیم‌شده ارسال می‌کند.

---

## 🎯 نمونه استفاده

فرض کنید آدرس اصلی پنل شما:

```text
https://server.example.com:2083/
```

باشد.

می‌توانید آن را با یک مسیر اختصاصی در دامنه خود ارائه کنید:

```text
https://your-domain.com/Hcctdhjiffhdsehj
```

به این ترتیب آدرس Backend اصلی در URL عمومی مورد استفاده قرار نمی‌گیرد.

---

## 🛠️ نصب دستی

اگر می‌خواهید پروژه را به‌صورت دستی دریافت کنید:

```bash
git clone https://github.com/Degeris/panel-proxy.git
cd panel-proxy
chmod +x install.sh
./install.sh
```

---

## 📂 Repository

🔗 **GitHub:**

https://github.com/Degeris/panel-proxy

---

## 🔐 نکته امنیتی

Panel Proxy آدرس Backend را از **URL عمومی** خارج می‌کند، اما این موضوع به معنی غیرقابل‌دسترسی یا غیرقابل‌شناسایی بودن Backend از روش‌های دیگر نیست.

برای امنیت بیشتر توصیه می‌شود:

- 🔒 دسترسی مستقیم Backend را محدود کنید.
- 🧱 Firewall مناسب تنظیم کنید.
- 🔑 Authentication را فعال کنید.
- 🔐 از HTTPS استفاده کنید.
- 🚫 اطلاعات حساس را داخل Repository عمومی قرار ندهید.

---

## 📄 License

این پروژه تحت License مشخص‌شده در فایل `LICENSE` منتشر شده است.

---

<p align="center">
  🚀 <b>Panel Proxy</b><br>
  <sub>Simple • Fast • Lightweight</sub>
</p>
