# 📈 Phân Tích Bài Toán Doanh Nghiệp (Olist E-Commerce Business Case)

Tài liệu này phân tích các bài toán kinh doanh cốt lõi của sàn thương mại điện tử **Olist (Brazil)** dựa trên dữ liệu thực tế. Mục tiêu là giúp bạn chuyển hướng từ việc chỉ làm kỹ thuật (SQL/ML) sang tư duy giải quyết vấn đề doanh nghiệp và trích xuất insight có thể hành động (actionable insights).

---

## 1. Bối Cảnh Doanh Nghiệp (Business Context)
Olist là một nền tảng marketplace kết nối các cửa hàng nhỏ (sellers) trên khắp Brazil với khách hàng. 
* **Mô hình kinh doanh:** B2B2C (Olist ăn hoa hồng từ các giao dịch của người bán).
* **Đặc thù thị trường Brazil:** Địa lý rộng lớn dẫn đến phí vận chuyển (freight value) cao và thời gian giao hàng (delivery time) kéo dài ở một số khu vực. Người dân có thói quen trả góp (installments) qua thẻ tín dụng hoặc thanh toán bằng hóa đơn ngân hàng (boleto).
* **Thách thức lớn nhất:** Tỷ lệ khách hàng mua một lần rồi rời đi (One-time buyers) rất cao, chi phí chuyển đổi/thu hút khách hàng mới (CAC - Customer Acquisition Cost) tăng dần, trong khi giá trị trọn đời của khách hàng (CLV - Customer Lifetime Value) chưa được tối ưu.

---

## 2. Số Liệu Nền Tảng Đã Kiểm Chứng (Verified Baseline Facts)

> Toàn bộ số liệu dưới đây được tính trực tiếp từ 9 file CSV gốc (kiểm chứng ngày 12/07/2026). Mọi nhận định trong tài liệu này đều neo vào các con số này — khi trình bày, dùng số thay vì tính từ ("97%" thay vì "rất cao").

| Chỉ số | Giá trị đã kiểm chứng | Ý nghĩa với bài toán |
| :--- | :--- | :--- |
| Tổng đơn hàng | **99,441** (04/09/2016 → 17/10/2018) | Quy mô dataset |
| Đơn `delivered` | **96,478 (97.0%)** — canceled 625, unavailable 609, shipped 1,107 | RFM chỉ tính trên delivered |
| Khách hàng thật | **96,096** `customer_unique_id` (so với 99,441 `customer_id`) — 93,358 khách có đơn delivered | Bằng chứng phải dùng `customer_unique_id` |
| **One-time buyers** | **97.0%** — chỉ **2,801 khách mua ≥2 lần**, max 15 đơn/khách | Thách thức lớn nhất của Olist, nay có số |
| Tổng doanh thu (delivered) | **R$ 15,422,462** | Tử số của AOV và CLV |
| AOV | **R$ 159.86** | Baseline trước khi tối ưu |
| CLV lịch sử | **≈ R$ 165/khách** (15.42M / 93,358) | Gần bằng AOV vì 97% khách chỉ mua 1 lần |
| Thanh toán | Credit card **76,795 giao dịch (~81% giá trị)**, boleto 19,784, voucher 5,775, debit 1,529. **66.85%** giao dịch credit card trả góp >1 kỳ | Xác nhận đặc thù trả góp của thị trường Brazil |
| Đơn nhiều dòng payment | **2,961 đơn** có ≥2 dòng trong bảng payments | Nguồn gốc bẫy nhân bản doanh thu khi JOIN |
| Giao hàng | Trung bình **12.5 ngày** (định nghĩa chuẩn hóa: hiệu 2 ngày lịch, khớp gold layer; nếu đo bằng hiệu timestamp làm tròn xuống thì ra 12.1); **8.11% đơn giao trễ** hơn ngày hẹn | Đầu vào Bài toán 3 |
| Review | Trung bình **4.09/5**; **14.69% đơn bị 1–2 sao** | Đầu vào Bài toán 3 |
| Pareto thực tế | Top 20% khách đóng góp **53.5%** doanh thu (KHÔNG phải 80/20) | Dashboard phải trình bày trung thực: Pareto yếu vì F≈1 |
| Khách chi đậm nhất | **R$ 13,664** | Outlier/wholesale cần xử lý khi clustering |

---

## 3. Giới Hạn Của Dữ Liệu (Data Limitations)

Ghi rõ giới hạn TRƯỚC khi phân tích để mọi khuyến nghị phía sau đứng vững khi bị chất vấn.

**Dữ liệu KHÔNG có (kiểm tra theo cột thực tế của 9 bảng):**
* **Chi phí marketing** → CAC thật không tính được. Mọi lập luận về CAC trong tài liệu này chỉ ở mức định tính (nguyên tắc "giữ khách cũ rẻ hơn kéo khách mới").
* **Giá vốn sản phẩm (COGS)** → CLV chỉ tính theo **doanh thu**/khách, không phải lợi nhuận/khách. Phải ghi rõ giả định này trên dashboard và README.
* **Nhân khẩu học khách hàng** (tuổi, giới tính, thu nhập) → phân khúc chỉ dựa trên hành vi mua (RFM), không dựa trên demographic.
* **Dữ liệu traffic/session** → không phân tích được phễu chuyển đổi trước khi đặt hàng.
* **Dữ liệu sau 10/2018** → mọi "hành động đề xuất" là mô phỏng khuyến nghị, không có vòng lặp đo lường thật.

**Điểm bất thường trong dữ liệu (đã kiểm chứng):**
* Năm 2016 chỉ có **329 đơn** (giai đoạn khởi động) → loại hoặc chú thích khi vẽ trend theo thời gian, nếu không đường trend sẽ gây hiểu lầm "tăng trưởng đột biến".
* **8 đơn** status `delivered` nhưng thiếu ngày giao thực tế → quyết định cách xử lý và ghi lại.
* Bảng reviews: 99,224 dòng nhưng chỉ **98,410 `review_id` duy nhất** → có trùng lặp, cần dedup trước khi tính điểm trung bình.
* Bảng geolocation: **1,000,163 dòng nhưng chỉ 19,015 zip prefix duy nhất** → gần như toàn bộ là trùng lặp, không đưa nguyên bảng vào model.

---

## 4. Định Nghĩa KPI Chuẩn (KPI Definitions)

Chốt công thức MỘT LẦN tại đây để Python, SQL và DAX cùng tính ra một con số. Quy ước chung: chỉ tính đơn `delivered`; doanh thu = `payment_value` đã gộp về mức đơn hàng; khách = `customer_unique_id`.

| KPI | Công thức (tử số / mẫu số) | Nguồn | Ghi chú quyết định |
| :--- | :--- | :--- | :--- |
| **AOV** | Tổng doanh thu / Số đơn distinct | Fact_Orders | Baseline: R$ 159.86 |
| **CLV (lịch sử)** | Tổng doanh thu / Số khách distinct | Fact_Orders | Theo doanh thu, không phải lợi nhuận (xem mục 3). Chỉ số M của RFM chính là CLV tính theo từng khách |
| **Repeat Rate** | Số khách có ≥2 **lần mua** (ngày mua distinct) / Tổng số khách | Fact_Orders | Baseline: **2.16%** (2,015/93,357). LƯU Ý: nếu đếm theo order_id thô ra 3.0%, nhưng 29.6% "đơn 2" là split orders (đơn cùng ngày cách nhau median 1 giây) — phải gộp về lần mua thật. One-time thực tế = **97.84%** |
| **Churn window** | — | Fact_RFM (recency) | Xác định bằng survival analysis, KHÔNG dùng quy ước 90 ngày (tại 90 ngày mới 55% khách quay lại → 45% bị dán nhãn mất oan). Hai ngưỡng: **cần can thiệp ~74–175 ngày** (median→P75), **đã rời bỏ ~288 ngày** (P90) |
| **Retention Rate (tháng)** | Số khách mua ở tháng T **và** tháng T−1 / Số khách mua ở tháng T−1 | Fact_Orders + Dim_Date | Cần Dim_Date để tính bằng time intelligence trong DAX |
| **Churn (proxy)** | % khách vượt ngưỡng "đã rời bỏ" **~288 ngày** kể từ lần mua gần nhất | Fact_RFM (recency) | Ngưỡng xác định bằng survival analysis (CDF inter-purchase time trên 2,015 khách mua lại thật) — xem notebook 02 phần 1. Thay cho quy ước 90 ngày ban đầu vốn quá ngắn |
| **Late Delivery Rate** | Số đơn có ngày giao thực tế > ngày hẹn / Số đơn delivered có ngày giao | Fact_Orders | Baseline: 8.11% |

---

## 5. 3 Bài Toán Doanh Nghiệp Cần Giải Quyết

### 📌 Bài toán 1: Tối ưu hóa tỷ lệ giữ chân khách hàng (Retention Rate) & Giảm Churn
Doanh nghiệp muốn biết: *Ai là người đang rời bỏ chúng ta? Làm sao để kéo họ quay lại trước khi quá muộn?*
* **Vấn đề kỹ thuật:** Sử dụng RFM (Recency - Frequency - Monetary) kết hợp K-Means Clustering để phân cụm tập khách hàng.
* **Góc nhìn doanh nghiệp:**
  * Xác định nhóm **At-risk** (Đã lâu không mua nhưng trước đó mua nhiều) và nhóm **Lost** (Đã mất hoàn toàn).
  * Tìm mối tương quan giữa tỷ lệ rời bỏ với các yếu tố vận hành như: Thời gian giao hàng thực tế vs. Dự kiến, phí ship cao, hay điểm đánh giá (review_score) kém.
  * **Hành động đề xuất:** Tạo chiến dịch Win-back tự động. Ví dụ: Gửi voucher giảm giá qua email cho nhóm "About to Sleep" ngay khi họ bước sang ngày thứ 60 không phát sinh giao dịch.
* **Câu hỏi phân tích cụ thể (checklist EDA — mỗi câu ghi rõ cột dữ liệu để trả lời):**
  1. Khách repeat (F≥2) khác khách one-time thế nào về điểm review trung bình và tỷ lệ bị giao trễ? → `review_score`, `delay_days`, frequency theo `customer_unique_id`
  2. Thời gian trung bình giữa đơn thứ 1 và đơn thứ 2 của 2,801 khách repeat là bao nhiêu ngày? → `order_purchase_timestamp` group theo `customer_unique_id`. *Đây là căn cứ dữ liệu để chọn ngưỡng churn 90 ngày và thời điểm gửi win-back, thay vì chọn đại.*
  3. Tỷ lệ mua lại có khác biệt giữa các bang không? → frequency × `customer_state`
  4. Khách có đơn ĐẦU TIÊN bị 1–2 sao thì tỷ lệ quay lại thấp hơn bao nhiêu so với khách có đơn đầu 4–5 sao? → `review_score` của đơn đầu × sự tồn tại của đơn thứ 2

### 📌 Bài toán 2: Tăng Giá Trị Đơn Hàng Trung Bình (AOV) & Giá Trị Trọn Đời (CLV)
Doanh nghiệp muốn biết: *Làm sao để khách hàng mua nhiều hơn trong một đơn và quay lại mua nhiều lần hơn?*
* **Vấn đề kỹ thuật:** Phân tích giỏ hàng, xu hướng thanh toán trả góp, các danh mục sản phẩm phổ biến của nhóm VIP.
* **Góc nhìn doanh nghiệp:**
  * Nhóm **Champions/VIP** mua gì? Họ dùng phương thức thanh toán nào? (Ví dụ: Nếu họ thích trả góp nhiều kỳ, cần làm việc với đối tác tài chính để tối ưu hóa phí giao dịch).
  * Có thể áp dụng Cross-selling (Bán chéo) hay Up-selling (Bán thêm) cho nhóm khách hàng trung thành thông qua các combo sản phẩm nào?
  * **Hành động đề xuất:** Thiết kế chương trình khách hàng thân thiết (Loyalty Program) dành riêng cho nhóm Champions. Gợi ý sản phẩm liên quan ngay tại trang thanh toán dựa trên hành vi mua hàng của nhóm này.
* **Câu hỏi phân tích cụ thể:**
  1. Danh mục sản phẩm nào có AOV cao nhất, và nhóm khách chi đậm nhất (top 10% theo M) tập trung mua danh mục gì? → `product_category_name_english`, `price` join qua `order_items`
  2. Đơn trả góp nhiều kỳ có giá trị cao hơn đơn thanh toán 1 lần bao nhiêu? → `payment_installments` × `payment_value`
  3. Bao nhiêu % đơn hàng có ≥2 sản phẩm? (dư địa cross-sell hiện tại) → max `order_item_id` theo `order_id`
  4. Phí ship chiếm bao nhiêu % giá trị đơn theo từng bang? Bang nào phí ship "nuốt" nhiều nhất? → `freight_value` / `price` × `customer_state`

### 📌 Bài toán 3: Quản lý Chất lượng Vận hành & Trải nghiệm Khách hàng (Logistics & Customer Experience)
Doanh nghiệp muốn biết: *Sự chậm trễ trong giao hàng và đánh giá tiêu cực ảnh hưởng thế nào đến lòng trung thành của khách hàng?*
* **Vấn đề kỹ thuật:** Phân tích mối liên hệ giữa RFM Segment và Review Score, Delivery Delay (Thời gian giao hàng thực tế - Thời gian ước tính).
* **Góc nhìn doanh nghiệp:**
  * Nhóm khách hàng rời đi (Lost/Hibernating) có phải do họ từng có trải nghiệm giao hàng tệ hại hoặc đánh giá 1 sao hay không?
  * Khu vực địa lý nào (state, city) có tỷ lệ khách hàng rời bỏ cao nhất do vấn đề logistics?
  * **Hành động đề xuất:** Cảnh báo bộ phận vận hành về các seller thường xuyên giao hàng trễ hoặc có review thấp ở các khu vực trọng điểm. Điều chỉnh thời gian giao hàng ước tính thực tế hơn để tránh làm khách hàng thất vọng.
* **Câu hỏi phân tích cụ thể:**
  1. Đơn giao trễ có điểm review trung bình thấp hơn đơn đúng hẹn bao nhiêu? → `delay_days > 0` × `review_score`
  2. 8.11% đơn giao trễ tập trung ở bang nào và seller nào? → `delay_days` × `customer_state`, `seller_id`
  3. Trong 14.69% đơn bị 1–2 sao, bao nhiêu % gắn với giao trễ? (tách nguyên nhân logistics khỏi nguyên nhân sản phẩm) → `review_score ≤ 2` × `delay_days`
  4. Thời gian giao trung bình của khách one-time so với khách repeat có khác biệt không? → `delivery_days` × frequency theo `customer_unique_id`. *Nếu có, đây là bằng chứng churn là vấn đề vận hành chứ không chỉ marketing — insight liên phòng ban đắt giá nhất của project.*

---

## 6. Bản Đồ Phân Khúc RFM & Chiến Lược Doanh Nghiệp (RFM Segment Action Plan)

Dựa trên phân cụm RFM, bạn cần hướng dẫn Power BI hiển thị các nhóm này và đề xuất giải pháp tương ứng:

| Tên Nhóm Khách Hàng | Đặc Điểm RFM (R-F-M) | Ý Nghĩa Doanh Nghiệp | Chiến Lược / Hành Động Cụ Thể (Actionable Insights) |
| :--- | :--- | :--- | :--- |
| **Champions (VIP)** | R thấp (mới mua), F cao (mua nhiều), M cao (chi đậm) | Khách hàng tốt nhất, mang lại doanh thu chính. | • Chương trình ưu đãi VIP, trải nghiệm sản phẩm mới trước.<br>• Không cần giảm giá sâu, tập trung vào dịch vụ chăm sóc cao cấp. |
| **Loyal Customers** | R trung bình, F cao, M trung bình-cao | Khách hàng mua thường xuyên và ổn định. | • Up-sell sản phẩm giá trị cao hơn.<br>• Khuyến khích viết đánh giá đổi quà để tăng tương tác. |
| **Potential Loyalists** | R thấp (mới mua), F trung bình, M trung bình | Khách hàng mới có tiềm năng trở thành loyal. | • Đề xuất sản phẩm liên quan (Recommendation System).<br>• Gửi chương trình tích điểm ngay sau đơn hàng thứ 2. |
| **New Customers** | R rất thấp (vừa mua), F thấp, M thấp | Khách hàng mới tinh, chưa rõ hành vi lâu dài. | • Gửi chuỗi email chào mừng (Welcome series).<br>• Hướng dẫn sử dụng dịch vụ và tặng voucher cho đơn hàng tiếp theo. |
| **About to Sleep** | R hơi cao, F thấp, M thấp | Sắp mất dấu, tần suất mua ít và đã lâu không quay lại. | • Gửi thông báo đẩy (push) gợi nhắc thương hiệu.<br>• Đề xuất các sản phẩm bán chạy nhất kèm ưu đãi giới hạn thời gian. |
| **At Risk / Can't Lose Them** | R cao, F cao, M cao | Khách hàng VIP cũ nhưng sắp rời bỏ. **Nguy hiểm nhất!** | • Liên hệ trực tiếp qua bộ phận CSKH để khảo sát trải nghiệm.<br>• Gửi ưu đãi đặc biệt "Chúng tôi nhớ bạn" với mức giảm giá lớn. |
| **Lost / Hibernating** | R rất cao, F rất thấp, M rất thấp | Khách hàng đã mất hoàn toàn. | • Không nên chi quá nhiều tiền marketing cho nhóm này (tối ưu CAC).<br>• Chỉ gửi email chiến dịch lớn (Black Friday, Tết) để xem ai kích hoạt lại. |

---

## 7. Gợi Ý Bố Cục Power BI Dashboard (Business-Oriented Layout)

Thay vì vẽ biểu đồ ngẫu nhiên, hãy thiết kế báo cáo Power BI chia làm 3 trang với mục tiêu rõ ràng:

### Trang 1: Executive Overview (Dành cho C-Level / Ban Giám Đốc)
* **Mục tiêu:** Nhìn nhanh sức khỏe doanh nghiệp.
* **KPIs chính (Cards):** Tổng Doanh thu, Tổng số Đơn hàng, Tổng số Khách hàng (Unique Customers), AOV (Giá trị đơn trung bình), Tỷ lệ Khách hàng quay lại (Repeat Rate).
* **Visuals:**
  * Biểu đồ đường xu hướng Doanh thu & Số lượng đơn hàng theo tháng.
  * Bản đồ Brazil thể hiện mật độ doanh thu theo các Bang (States).
  * Biểu đồ tròn/thanh thể hiện cơ cấu doanh thu theo Phương thức thanh toán (Credit Card, Boleto, Voucher...).

### Trang 2: Customer Segmentation & RFM (Dành cho Marketing Manager)
* **Mục tiêu:** Hiểu sâu về các phân khúc khách hàng để chạy chiến dịch.
* **Visuals:**
  * Biểu đồ Treemap/Donut thể hiện tỷ lệ % số lượng khách hàng và % doanh thu đóng góp của từng nhóm RFM. Lưu ý: Pareto thực tế của Olist là **53.5/20** chứ không phải 80/20 (xem mục 2) — trình bày trung thực con số này và giải thích vì sao (97% one-time buyers) thay vì ép theo khuôn 80/20.
  * Biểu đồ Scatter Plot (Recency vs. Monetary, kích thước bóng là Frequency) để trực quan hóa các cụm.
  * Bảng chi tiết danh sách khách hàng thuộc từng cụm (hỗ trợ filter xuất file Excel để Marketing chạy Ads/Email).

### Trang 3: Operations & Logistics Impact (Dành cho Operations Manager)
* **Mục tiêu:** Tìm ra nguyên nhân khiến khách hàng không hài lòng dẫn đến churn.
* **Visuals:**
  * Biểu đồ cột so sánh thời gian giao hàng thực tế trung bình của từng nhóm RFM (Nhóm Lost có bị giao hàng chậm hơn Champions không?).
  * Biểu đồ tương quan giữa Phí Ship (Freight Value) và Điểm đánh giá (Review Score).
  * Top các Seller bị đánh giá tệ nhất và có tỷ lệ giao hàng trễ cao nhất.
