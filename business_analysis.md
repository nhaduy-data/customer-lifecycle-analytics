# Phân Tích Bài Toán Doanh Nghiệp (Olist E-Commerce Business Case)

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
| Giao hàng | Trung bình **12.5 ngày** (hiệu hai ngày lịch); **6.77% đơn giao sau ngày hẹn** (8.11% nếu so theo timestamp, khi đó đơn giao đúng ngày hẹn cũng bị tính là trễ vì mốc hẹn là 0 giờ) | Đầu vào cho phân tích vận hành |
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
| **Late Delivery Rate** | Số đơn có ngày giao thực tế > ngày hẹn (so theo ngày lịch, cột `order_delay_day > 0`) / Số đơn delivered có ngày giao | Fact_Orders | Baseline: **6.77%**. Không so theo timestamp: cách đó cho 8.11% vì đơn giao đúng ngày hẹn cũng bị tính là trễ |

---

## 5. Ba Bài Toán Doanh Nghiệp Cần Giải Quyết

Ba bài toán nối tiếp nhau theo thứ tự: mô tả tệp khách hàng, xác định thời điểm can thiệp, tìm nguyên nhân. Mỗi bài toán được trả lời trong một notebook. Với mỗi bài toán, tài liệu ghi lại **giả thuyết ban đầu** trước khi phân tích, để phần phân tích có thể xác nhận hoặc bác bỏ nó; kết quả cuối cùng được tổng hợp trong README, mục 3.

### Bài toán 1: Khách hàng gồm những ai, nhóm nào đáng đầu tư? — `notebooks/01_eda_rfm_kmeans.ipynb`
Doanh nghiệp muốn biết: *Tệp khách hàng có cấu trúc thế nào, và ngân sách giữ chân nên dồn vào đâu?*
* **Giả thuyết ban đầu:** tệp khách có thể chia thành các nhóm quen thuộc như bản đồ ở mục 6 (Champions, Loyal, At Risk, Lost...), và tồn tại một nhóm khách trung thành đủ lớn để xây chương trình khách hàng thân thiết.
* **Câu hỏi kiểm chứng:**
  1. Ba chỉ số Recency, Frequency, Monetary phân bố ra sao; chỉ số nào thực sự phân biệt được khách hàng?
  2. Bao nhiêu cụm là hợp lý, xét theo thống kê (elbow, silhouette) và theo khả năng hành động?
  3. Mỗi phân khúc chiếm bao nhiêu khách và bao nhiêu doanh thu; nhóm nào cần ưu tiên?
  4. Chấm điểm RFM truyền thống có cho kết quả khác K-Means không, và khác ở đâu?
* **Hành động phụ thuộc kết quả:** thứ tự ưu tiên ngân sách theo phân khúc; có hay không chương trình khách hàng thân thiết.

### Bài toán 2: Khi nào một khách được coi là đã mất, can thiệp lúc nào và đáng bao nhiêu tiền? — `notebooks/02_advanced_analysis.ipynb`
Doanh nghiệp muốn biết: *Ngưỡng nào để kích hoạt chiến dịch win-back, và chi tối đa bao nhiêu cho mỗi khách thì còn có lãi?*
* **Giả thuyết ban đầu:** quy ước 90 ngày không mua là đã rời bỏ đủ dùng cho Olist; chiến dịch win-back có lãi nếu đạt uplift vài phần trăm.
* **Câu hỏi kiểm chứng:**
  1. Thời gian giữa lần mua thứ nhất và thứ hai phân bố ra sao; ngưỡng nào là "cần can thiệp" và ngưỡng nào là "đã mất"?
  2. Trong sáu tháng, khách dịch chuyển giữa các trạng thái vòng đời thế nào, và bao nhiêu giá trị đi theo?
  3. Tỷ lệ tự quay lại khi không can thiệp là bao nhiêu? Đây là con số nền để đo hiệu quả mọi chiến dịch.
  4. Với chi phí và uplift nào thì win-back hòa vốn, và kiểm chứng uplift bằng thí nghiệm nào?
* **Hành động phụ thuộc kết quả:** ngưỡng kích hoạt chiến dịch; quy tắc chi phí tối đa mỗi khách; thiết kế A/B test.

### Bài toán 3: Vì sao khách không quay lại, và vận hành sửa được gì? — `notebooks/03_experience_operations_repeat.ipynb`
Doanh nghiệp muốn biết: *Trải nghiệm mua hàng có phải lý do khách không quay lại không, và nếu sửa vận hành thì được gì?*
* **Giả thuyết ban đầu:** khách rời đi vì trải nghiệm giao hàng xấu (giao trễ, phí vận chuyển cao, đánh giá thấp); giá trị khách có thể tăng bằng bán chéo trong giỏ hàng và khuyến khích trả góp.
* **Câu hỏi kiểm chứng:**
  1. Khách có lần mua đầu bị đánh giá 1–2 sao hoặc giao trễ quay lại ít hơn bao nhiêu so với khách hài lòng?
  2. Tỷ lệ mua lại, tỷ lệ giao trễ và phí vận chuyển khác nhau thế nào giữa các vùng, và có cùng thứ tự không?
  3. Giao trễ làm điểm đánh giá giảm bao nhiêu, và bao nhiêu phần đánh giá xấu là do giao hàng?
  4. Ngày giao dự kiến đang được đặt gần hay xa so với thực tế, và giao sớm hơn có làm khách hài lòng hơn không?
  5. Giao trễ tập trung ở seller nào; bao nhiêu phần chậm trễ đến từ việc seller và khách ở khác bang?
  6. Giỏ hàng có bao nhiêu sản phẩm; khách quay lại có mua cùng danh mục hoặc cùng seller không; lần mua đầu ở danh mục nào thì hay quay lại?
* **Hành động phụ thuộc kết quả:** có coi logistics là đòn bẩy giữ chân hay chỉ là đòn bẩy bảo vệ điểm đánh giá; danh sách seller cần hỗ trợ; rút ngắn hay giữ ngày hẹn giao; nội dung chiến dịch win-back (bán chéo hay gợi ý cùng danh mục).

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
