# 📈 Phân Tích Bài Toán Doanh Nghiệp (Olist E-Commerce Business Case)

Tài liệu này xác định các bài toán kinh doanh cốt lõi của sàn thương mại điện tử **Olist (Brazil)** dựa trên dữ liệu thực tế, cùng các số liệu nền tảng và định nghĩa KPI làm cơ sở cho toàn bộ phân tích. Mục tiêu là chuyển từ xử lý kỹ thuật thuần túy (SQL/ML) sang giải quyết vấn đề doanh nghiệp và trích xuất insight có thể hành động.

---

## 1. Bối Cảnh Doanh Nghiệp (Business Context)
Olist là một nền tảng marketplace kết nối các cửa hàng nhỏ (sellers) trên khắp Brazil với khách hàng. 
* **Mô hình kinh doanh:** B2B2C (Olist ăn hoa hồng từ các giao dịch của người bán).
* **Đặc thù thị trường Brazil:** Địa lý rộng lớn dẫn đến phí vận chuyển (freight value) cao và thời gian giao hàng (delivery time) kéo dài ở một số khu vực. Người dân có thói quen trả góp (installments) qua thẻ tín dụng hoặc thanh toán bằng hóa đơn ngân hàng (boleto).
* **Thách thức lớn nhất:** Tỷ lệ khách hàng mua một lần rồi rời đi (One-time buyers) rất cao, chi phí chuyển đổi/thu hút khách hàng mới (CAC - Customer Acquisition Cost) tăng dần, trong khi giá trị trọn đời của khách hàng (CLV - Customer Lifetime Value) chưa được tối ưu.

---

## 2. Số Liệu Nền Tảng Đã Kiểm Chứng (Verified Baseline Facts)

> Toàn bộ số liệu dưới đây được tính trực tiếp từ 9 file CSV gốc. Mọi nhận định trong tài liệu này đều neo vào các con số đã kiểm chứng này.

| Chỉ số | Giá trị đã kiểm chứng | Ý nghĩa với bài toán |
| :--- | :--- | :--- |
| Tổng đơn hàng | **99,441** (04/09/2016 → 17/10/2018) | Quy mô dataset |
| Đơn `delivered` | **96,478 (97.0%)** — canceled 625, unavailable 609, shipped 1,107 | Phân tích RFM chỉ tính trên đơn đã giao thành công |
| Khách hàng thật | **96,096** `customer_unique_id` (so với 99,441 `customer_id`) — 93,357 khách có đơn delivered | `customer_id` sinh mới theo từng đơn nên không dùng để định danh khách |
| **One-time buyers** | **97.0%** theo `order_id` thô — chỉ 2,801 khách có ≥2 đơn. Sau khi loại đơn bị tách (xem mục 4): **97.84%**, chỉ 2,015 khách thực sự mua lại | Thách thức lớn nhất của Olist |
| Tổng doanh thu (delivered) | **R$ 15,422,462** | Cơ sở tính AOV và CLV |
| AOV | **R$ 159.86** | Giá trị trung bình mỗi đơn hàng |
| CLV lịch sử | **R$ 165/khách** (15.42M / 93,357) | Gần bằng AOV vì gần như mọi khách chỉ mua một lần |
| Thanh toán | Credit card **76,795 giao dịch (~81% giá trị)**, boleto 19,784, voucher 5,775, debit 1,529. **66.85%** giao dịch credit card trả góp >1 kỳ | Xác nhận đặc thù trả góp của thị trường Brazil |
| Đơn nhiều dòng payment | **2,961 đơn** có ≥2 dòng trong bảng payments | Cần gộp về mức đơn hàng trước khi JOIN để tránh nhân bản doanh thu |
| Giao hàng | Trung bình **12.5 ngày** (hiệu hai ngày lịch); **8.11% đơn giao trễ** hơn ngày hẹn | Đầu vào cho phân tích vận hành |
| Review | Trung bình **4.09/5**; **14.69% đơn bị 1–2 sao** | Đầu vào cho phân tích trải nghiệm khách hàng |
| Pareto thực tế | Top 20% khách đóng góp **53.5%** doanh thu, không phải 80/20 | Mức tập trung thấp hơn thông lệ vì gần như mọi khách chỉ mua một lần |
| Khách chi đậm nhất | **R$ 13,664** | Khách mua sỉ, không phải lỗi dữ liệu — giữ lại và xử lý bằng log transform |

---

## 3. Giới Hạn Của Dữ Liệu (Data Limitations)

Các giới hạn dưới đây được xác định trước khi phân tích, làm cơ sở đánh giá phạm vi hiệu lực của mọi kết luận.

**Dữ liệu KHÔNG có (kiểm tra theo cột thực tế của 9 bảng):**
* **Chi phí marketing** → CAC thật không tính được. Mọi lập luận về CAC trong tài liệu này chỉ ở mức định tính (nguyên tắc "giữ khách cũ rẻ hơn kéo khách mới").
* **Giá vốn sản phẩm (COGS)** → CLV chỉ tính theo **doanh thu**/khách, không phải lợi nhuận/khách.
* **Nhân khẩu học khách hàng** (tuổi, giới tính, thu nhập) → phân khúc chỉ dựa trên hành vi mua (RFM), không dựa trên demographic.
* **Dữ liệu traffic/session** → không phân tích được phễu chuyển đổi trước khi đặt hàng.
* **Dữ liệu sau 10/2018** → các khuyến nghị không thể kiểm chứng bằng kết quả thực tế.

**Điểm bất thường trong dữ liệu (đã kiểm chứng):**
* Năm 2016 chỉ có **329 đơn** (giai đoạn khởi động) → được loại khỏi phân tích xu hướng theo thời gian vì mẫu quá nhỏ.
* **8 đơn** status `delivered` nhưng thiếu ngày giao thực tế → giữ giá trị NULL, không suy diễn.
* Bảng reviews: 99,224 dòng nhưng chỉ **98,410 `review_id` duy nhất** → có trùng lặp, đã khử trùng lặp trước khi tính điểm trung bình.
* Bảng geolocation: **1,000,163 dòng nhưng chỉ 19,015 zip prefix duy nhất** → gần như toàn bộ là trùng lặp, không đưa vào mô hình dữ liệu.

---

## 4. Định Nghĩa KPI Chuẩn (KPI Definitions)

Công thức được thống nhất tại đây để Python, SQL và DAX cùng cho ra một kết quả. Quy ước chung: chỉ tính đơn `delivered`; doanh thu = `payment_value` đã gộp về mức đơn hàng; khách = `customer_unique_id`.

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
  * **Hành động đề xuất:** Chiến dịch win-back tự động, kích hoạt tại ngưỡng can thiệp ~175 ngày không phát sinh giao dịch (ngưỡng xác định bằng survival analysis, xem mục 4).
* **Câu hỏi phân tích:**
  1. Khách mua lại khác khách một lần thế nào về điểm review trung bình và tỷ lệ bị giao trễ?
  2. Thời gian giữa lần mua thứ nhất và thứ hai phân bố ra sao? Đây là căn cứ dữ liệu để xác định ngưỡng churn và thời điểm can thiệp.
  3. Tỷ lệ mua lại có khác biệt giữa các vùng địa lý không?
  4. Khách có đơn hàng đầu tiên bị đánh giá 1–2 sao thì tỷ lệ quay lại thấp hơn bao nhiêu so với khách có đơn đầu 4–5 sao?

### 📌 Bài toán 2: Tăng Giá Trị Đơn Hàng Trung Bình (AOV) & Giá Trị Trọn Đời (CLV)
Doanh nghiệp muốn biết: *Làm sao để khách hàng mua nhiều hơn trong một đơn và quay lại mua nhiều lần hơn?*
* **Vấn đề kỹ thuật:** Phân tích giỏ hàng, xu hướng thanh toán trả góp, các danh mục sản phẩm phổ biến của nhóm VIP.
* **Góc nhìn doanh nghiệp:**
  * Nhóm **Champions/VIP** mua gì? Họ dùng phương thức thanh toán nào? (Ví dụ: Nếu họ thích trả góp nhiều kỳ, cần làm việc với đối tác tài chính để tối ưu hóa phí giao dịch).
  * Có thể áp dụng Cross-selling (Bán chéo) hay Up-selling (Bán thêm) cho nhóm khách hàng trung thành thông qua các combo sản phẩm nào?
  * **Hành động đề xuất:** Thiết kế chương trình khách hàng thân thiết (Loyalty Program) dành riêng cho nhóm Champions. Gợi ý sản phẩm liên quan ngay tại trang thanh toán dựa trên hành vi mua hàng của nhóm này.
* **Câu hỏi phân tích cụ thể:**
  1. Danh mục sản phẩm nào có AOV cao nhất, và nhóm khách chi tiêu cao nhất tập trung mua danh mục gì?
  2. Đơn trả góp nhiều kỳ có giá trị cao hơn đơn thanh toán một lần bao nhiêu?
  3. Bao nhiêu phần trăm đơn hàng có từ hai sản phẩm trở lên? (khả năng bán chéo hiện tại)
  4. Phí vận chuyển chiếm bao nhiêu phần trăm giá trị đơn theo từng vùng?

### 📌 Bài toán 3: Quản lý Chất lượng Vận hành & Trải nghiệm Khách hàng (Logistics & Customer Experience)
Doanh nghiệp muốn biết: *Sự chậm trễ trong giao hàng và đánh giá tiêu cực ảnh hưởng thế nào đến lòng trung thành của khách hàng?*
* **Vấn đề kỹ thuật:** Phân tích mối liên hệ giữa RFM Segment và Review Score, Delivery Delay (Thời gian giao hàng thực tế - Thời gian ước tính).
* **Góc nhìn doanh nghiệp:**
  * Nhóm khách hàng rời đi (Lost/Hibernating) có phải do họ từng có trải nghiệm giao hàng tệ hại hoặc đánh giá 1 sao hay không?
  * Khu vực địa lý nào (state, city) có tỷ lệ khách hàng rời bỏ cao nhất do vấn đề logistics?
  * **Hành động đề xuất:** Cảnh báo bộ phận vận hành về các seller thường xuyên giao hàng trễ hoặc có review thấp ở các khu vực trọng điểm. Điều chỉnh thời gian giao hàng ước tính thực tế hơn để tránh làm khách hàng thất vọng.
* **Câu hỏi phân tích cụ thể:**
  1. Đơn giao trễ có điểm review trung bình thấp hơn đơn đúng hẹn bao nhiêu?
  2. Các đơn giao trễ tập trung ở vùng địa lý nào?
  3. Trong số đơn bị đánh giá 1–2 sao, bao nhiêu phần trăm gắn với giao hàng trễ? (tách nguyên nhân vận hành khỏi nguyên nhân sản phẩm)
  4. Thời gian giao hàng trung bình của khách mua một lần so với khách mua lại có khác biệt không? Nếu có, đây là bằng chứng cho thấy việc khách rời đi là vấn đề vận hành chứ không chỉ marketing.

---

## 6. Bản Đồ Phân Khúc RFM & Chiến Lược Doanh Nghiệp (RFM Segment Action Plan)

Bảng dưới đây là khung chiến lược tham chiếu theo các phân khúc RFM phổ biến, dùng làm cơ sở đối chiếu khi diễn giải kết quả phân cụm thực tế:

| Tên Nhóm Khách Hàng | Đặc Điểm RFM (R-F-M) | Ý Nghĩa Doanh Nghiệp | Chiến Lược / Hành Động Cụ Thể (Actionable Insights) |
| :--- | :--- | :--- | :--- |
| **Champions (VIP)** | R thấp (mới mua), F cao (mua nhiều), M cao (chi đậm) | Khách hàng tốt nhất, mang lại doanh thu chính. | • Chương trình ưu đãi VIP, trải nghiệm sản phẩm mới trước.<br>• Không cần giảm giá sâu, tập trung vào dịch vụ chăm sóc cao cấp. |
| **Loyal Customers** | R trung bình, F cao, M trung bình-cao | Khách hàng mua thường xuyên và ổn định. | • Up-sell sản phẩm giá trị cao hơn.<br>• Khuyến khích viết đánh giá đổi quà để tăng tương tác. |
| **Potential Loyalists** | R thấp (mới mua), F trung bình, M trung bình | Khách hàng mới có tiềm năng trở thành loyal. | • Đề xuất sản phẩm liên quan (Recommendation System).<br>• Gửi chương trình tích điểm ngay sau đơn hàng thứ 2. |
| **New Customers** | R rất thấp (vừa mua), F thấp, M thấp | Khách hàng mới tinh, chưa rõ hành vi lâu dài. | • Gửi chuỗi email chào mừng (Welcome series).<br>• Hướng dẫn sử dụng dịch vụ và tặng voucher cho đơn hàng tiếp theo. |
| **About to Sleep** | R hơi cao, F thấp, M thấp | Sắp mất dấu, tần suất mua ít và đã lâu không quay lại. | • Gửi thông báo đẩy (push) gợi nhắc thương hiệu.<br>• Đề xuất các sản phẩm bán chạy nhất kèm ưu đãi giới hạn thời gian. |
| **At Risk / Can't Lose Them** | R cao, F cao, M cao | Khách hàng VIP cũ nhưng sắp rời bỏ. **Nguy hiểm nhất!** | • Liên hệ trực tiếp qua bộ phận CSKH để khảo sát trải nghiệm.<br>• Gửi ưu đãi đặc biệt "Chúng tôi nhớ bạn" với mức giảm giá lớn. |
| **Lost / Hibernating** | R rất cao, F rất thấp, M rất thấp | Khách hàng đã mất hoàn toàn. | • Không nên chi quá nhiều tiền marketing cho nhóm này (tối ưu CAC).<br>• Chỉ gửi email chiến dịch lớn (Black Friday, Tết) để xem ai kích hoạt lại. |
