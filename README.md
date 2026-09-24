🚀 Panel Proxy

Panel Proxy یک ابزار ساده برای قرار دادن آدرس اصلی پنل یا سرویس شما پشت یک دامنه و یک مسیر اختصاصی است.

💡 کاربرد پروژه

اگر برای مثال یک پنل ادمینی، پنل مدیریت سرویس، API یا سرویس آنلاین دارید و نمی‌خواهید آدرس اصلی آن مستقیماً در اختیار کاربران قرار بگیرد، می‌توانید آدرس اصلی را پشت دامنه خودتان قرار دهید.

برای مثال، به‌جای اینکه آدرس اصلی پنل را به کاربر بدهید:

https://server.example.com:2083/xxxxx

می‌توانید یک آدرس تمیز و اختصاصی داشته باشید:

https://your-domain.com/Hcctdhjiffhdsehj

Panel Proxy درخواست را از مسیر ایجادشده دریافت کرده و به Backend اصلی ارسال می‌کند.

🔥 مناسب برای

- فروش و ارائه پنل‌های ادمینی
- سرویس‌های آنلاین
- API و Backendها
- سرویس‌های اشتراکی
- مخفی نگه داشتن آدرس مستقیم Backend
- قرار دادن چند سرویس پشت یک دامنه
- ایجاد URLهای اختصاصی و کوتاه برای سرویس‌ها

⚙️ نحوه کار

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

یعنی کاربر فقط آدرس دامنه و مسیر اختصاصی را مشاهده می‌کند و آدرس مستقیم Backend در URL عمومی استفاده نمی‌شود.

⚡ نصب سریع

bash <(curl -fsSL https://raw.githubusercontent.com/Degeris/panel-proxy/main/install.sh)

یا از طریق Git:

git clone https://github.com/Degeris/panel-proxy.git
cd panel-proxy
chmod +x install.sh
./install.sh

🔗 GitHub

https://github.com/Degeris/panel-proxy

«نکته: این ابزار آدرس Backend را از دید URL عمومی پنهان می‌کند؛ اما به‌تنهایی تضمین نمی‌کند که Backend در برابر روش‌های دیگر شناسایی یا دسترسی مستقیم کاملاً غیرقابل‌دسترسی باشد. برای امنیت واقعی، دسترسی مستقیم Backend را نیز با Firewall، Authentication و تنظیمات مناسب محدود کنید.»
