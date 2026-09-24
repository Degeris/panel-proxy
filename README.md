
---

⚡ نصب سریع

برای نصب مستقیم آخرین نسخه، دستور زیر را در ترمینال سرور اجرا کنید:

``` bash <(curl -fsSL https://raw.githubusercontent.com/Degeris/panel-proxy/main/install.sh) ```

«📋 برای کپی کردن دستور، روی دکمه Copy بالای کادر کد کلیک کنید.»

---

📌 معرفی

Panel Proxy ابزاری برای قرار دادن آدرس اصلی پنل یا سرویس شما پشت یک دامنه و مسیر اختصاصی است.

برای مثال، اگر برای فروش یا ارائه‌ی پنل ادمینی یک آدرس اصلی دارید و می‌خواهید کاربران به‌جای آدرس مستقیم، از یک آدرس روی دامنه‌ی شما استفاده کنند، می‌توانید آن Backend را پشت Panel Proxy قرار دهید.

🔗 مثال

آدرس اصلی:

https://server.example.com:2083/xxxxx

آدرس قابل ارائه به کاربر:

https://your-domain.com/Hcctdhjiffhdsehj

کاربر از طریق آدرس دوم به سرویس متصل می‌شود و Panel Proxy درخواست‌ها را به Backend اصلی هدایت می‌کند.

---

✨ امکانات

- 🔗 قرار دادن Backend پشت دامنه
- 🎲 ساخت مسیرهای تصادفی و اختصاصی
- 🔄 Reverse Proxy
- 🌐 پشتیبانی از Domain
- 📦 مناسب برای ارائه و فروش سرویس
- ⚡ نصب سریع و ساده
- 🖥️ مناسب برای سرورهای Linux

---

💡 کاربرد

این پروژه می‌تواند برای مواردی مانند:

- پنل‌های ادمینی
- API و Backend
- سرویس‌های آنلاین
- پنل‌های مدیریتی
- سرویس‌های اشتراکی
- ارائه‌ی آدرس اختصاصی برای کاربران

استفاده شود.

---

⚙️ نحوه عملکرد

User
 │
 ▼
your-domain.com
 │
 ▼
/Hcctdhjiffhdsehj
 │
 ▼
Panel Proxy
 │
 ▼
Original Backend

Panel Proxy درخواست دریافت‌شده از مسیر اختصاصی را به Backend تنظیم‌شده ارسال می‌کند.

---

🛠️ نصب دستی

در صورت نیاز می‌توانید Repository را Clone کرده و Installer را اجرا کنید:

git clone https://github.com/Degeris/panel-proxy.git
cd panel-proxy
chmod +x install.sh
./install.sh

---

🔗 Repository

https://github.com/Degeris/panel-proxy

---

⚠️ نکته امنیتی

Panel Proxy باعث می‌شود آدرس Backend در URL عمومی استفاده نشود، اما به‌تنهایی تضمین نمی‌کند Backend از روش‌های دیگر قابل شناسایی یا دسترسی مستقیم نباشد.

برای امنیت بیشتر، دسترسی مستقیم Backend را با Firewall، Authentication و تنظیمات مناسب محدود کنید.

---

📄 License

برای اطلاعات مربوط به License پروژه، فایل "LICENSE" را مشاهده کنید.
