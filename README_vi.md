# Tối ưu vòng đời khách hàng — RFM & K-Means trên Olist E-commerce

> Pipeline phân tích end-to-end (PostgreSQL → Python → Power BI) tìm hiểu vì sao 97,8% khách hàng
> Olist không bao giờ quay lại, và định lượng chi phí để thay đổi điều đó.

*English version: [README.md](README.md)*

---

## 1. Bối cảnh và bài toán

[Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) là sàn thương mại điện tử B2B2C
tại Brazil, kết nối người bán nhỏ với khách hàng trên toàn quốc. Dự án phân tích 96.477 đơn hàng đã
giao thành công (09/2016 – 08/2018) của 93.357 khách hàng.

**Vấn đề cốt lõi:** Giá trị vòng đời khách hàng (CLV, R$165) gần như bằng giá trị đơn hàng trung bình
(AOV, R$160). Ở một doanh nghiệp bán lẻ khỏe mạnh, CLV phải gấp nhiều lần AOV — vì khách quay lại
mua tiếp. Tại Olist thì không: chỉ **2,16% khách hàng từng mua lần thứ hai**, và tỷ lệ mua lại theo
tháng chưa bao giờ vượt 1%. Doanh thu tăng trưởng gần như hoàn toàn nhờ thu hút khách mới, không
phải nhờ giữ chân khách cũ.

**Ba câu hỏi dự án trả lời:**

1. **Khách hàng gồm những ai, nhóm nào đáng đầu tư?** (Phân khúc RFM + K-Means)
2. **Khi nào một khách thực sự được coi là đã mất, và khi nào nên can thiệp?** (Phân tích sống sót,
   dịch chuyển vòng đời)
3. **Giao hàng chậm có phải nguyên nhân khách rời đi — và chiến dịch win-back đáng giá bao nhiêu?**
   (Phân tích logistics, mô phỏng business case, thiết kế A/B test)

---

## 2. Kiến trúc

```
Kaggle CSV (9 file)
        │  COPY
        ▼
┌─────────────────────────────────────────────┐
│  PostgreSQL — olist_db                      │
│                                             │
│  BRONZE  9 bảng thô (giữ nguyên như nguồn)  │
│     │    làm sạch + biến đổi bằng SQL       │
│     ▼                                       │
│  GOLD    Star schema — 4 dim, 3 fact        │
└──────┬────────────────────────▲─────────────┘
       │ SQLAlchemy             │ to_sql()
       ▼                        │
┌──────────────────────────────────────┐
│  Python (Jupyter)                    │
│  RFM · K-Means · phân tích sống sót  │
│  dịch chuyển vòng đời · business case│
└──────────────────────────────────────┘
       │
       ▼  Import mode
┌──────────────────────────────────────┐
│  Power BI — dashboard 5 trang        │
└──────────────────────────────────────┘
```

**Tầng Gold (star schema):** `dim_customers`, `dim_products`, `dim_sellers`, `dim_date` ·
`fact_orders` (grain: 1 đơn hàng), `fact_order_items` (grain: 1 dòng sản phẩm),
`fact_rfm_segments` (grain: 1 khách × 1 kỳ snapshot).

**Vì sao hai tầng, không phải ba:** Mô hình Medallion phổ biến có ba tầng — Bronze (dữ liệu thô),
Silver (dữ liệu đã làm sạch), Gold (dữ liệu đã mô hình hóa cho phân tích). Dự án này chỉ dùng hai
tầng: các bước làm sạch vốn thuộc về Silver (lọc đơn đã giao, gộp thanh toán về mức đơn hàng, khử
trùng lặp đánh giá, chọn địa chỉ gần nhất cho mỗi khách) được thực hiện ngay trong câu lệnh nạp
Bronze → Gold, thay vì lưu thành một tầng bảng riêng.

Tầng Silver riêng biệt phát huy giá trị khi nhiều bảng Gold cùng dùng chung logic làm sạch (tách ra
để tái sử dụng), khi có nhiều nguồn dữ liệu cần chuẩn hóa trước khi ghép, hoặc khi các nhóm khác
nhau phụ trách làm sạch và mô hình hóa. Dự án này chỉ có một nguồn và một người thực hiện, nên tách
thêm một tầng chỉ làm phức tạp quy trình mà không mang lại lợi ích vận hành nào.

---

## 3. Các phát hiện chính

### 3.1 Chỉ 2,16% khách hàng từng quay lại — thấp hơn con số thô

Đếm đơn giản cho ra 3,0% khách mua lại. Điều tra một bất thường (25% "đơn hàng thứ hai" phát sinh
*cùng ngày* với đơn đầu) phát hiện đây là **đơn bị tách**: một lần thanh toán bị chia thành nhiều
`order_id` khi giỏ hàng chứa sản phẩm từ nhiều người bán khác nhau. Kiểm chứng ở mức timestamp —
khoảng cách trung vị giữa các đơn này chỉ **1 giây**, loại trừ hoàn toàn khả năng đây là hành vi mua
lại thật.

Sau khi định nghĩa lại một "lần mua" là một *ngày mua riêng biệt*, số khách mua lại thật giảm từ
2.801 xuống **2.015 (2,16%)**. Vấn đề giữ chân nghiêm trọng hơn con số thô thể hiện.

### 3.2 Quy ước churn 90 ngày phân loại nhầm 45% khách sẽ quay lại

Phân tích sống sót trên thời gian giữa các lần mua cho thấy tại mốc 90 ngày, mới chỉ **55%** khách
*sẽ* quay lại đã thực sự quay lại. Hai ngưỡng dựa trên dữ liệu thay cho quy ước chung:

| Ngưỡng | Giá trị | Mục đích sử dụng |
| :-- | :-- | :-- |
| Cần can thiệp | ~175 ngày (P75) | Thời điểm nên kích hoạt chiến dịch giữ chân |
| Đã rời bỏ | ~288 ngày (P90) | Thời điểm coi khách hàng là đã mất |

Hai ngưỡng này xác nhận độc lập kết quả K-Means: cụm *At Risk* có recency trung bình 286 ngày —
đúng ngay ranh giới rời bỏ mà đường cong sống sót chỉ ra.

### 3.3 39,5% doanh thu nằm ở nhóm khách đã ngừng mua

Phân cụm K-Means (K=5) trên dữ liệu RFM đã log-transform và chuẩn hóa:

| Phân khúc | Số khách | Recency | Monetary | % doanh thu |
| :-- | --: | --: | --: | --: |
| At Risk | 11.987 (12,8%) | 286 ngày | R$508,57 | **39,5%** |
| Potential Loyalist | 28.936 (31,0%) | 130 ngày | R$161,52 | 30,3% |
| Lost | 24.552 (26,3%) | 424 ngày | R$99,62 | 15,9% |
| Low-Value Occasional | 25.081 (26,9%) | 161 ngày | R$53,52 | 8,7% |
| Repeat Buyers | 2.801 (3,0%) | 221 ngày | R$308,59 | 5,6% |

Hai sự *vắng mặt* có ý nghĩa không kém các phân khúc hiện có: dữ liệu **không có nhóm Champions**
(mua gần đây + mua nhiều lần + chi tiêu cao) và **không có nhóm New Customers** — cụm gần đây nhất
cũng đã 130 ngày không phát sinh giao dịch. Olist chưa xây được tầng khách hàng trung thành.

Phương pháp chấm điểm RFM truyền thống không tách được hai nhóm giá trị nhất: *At Risk* (7,08) và
*Potential Loyalist* (7,37) có tổng điểm gần như bằng nhau, vì điểm Monetary cao bù cho điểm Recency
thấp. Hai nhóm này cộng lại nắm 69,8% doanh thu nhưng cần chiến lược trái ngược nhau — đây chính là
lý do phân cụm mang lại giá trị hơn chấm điểm theo luật.

### 3.4 Giao hàng chậm không phải nguyên nhân churn — nhưng ảnh hưởng nặng nhất đến nhóm giá trị cao

Trái với giả thuyết ban đầu, nhóm *Lost* có tỷ lệ giao trễ **thấp nhất** (4,1%), trong khi *At Risk*
— nhóm nắm 39,5% doanh thu — có tỷ lệ **cao nhất** (8,5%).

Phân rã thời gian giao hàng thành ba khâu xác định chính xác điểm nghẽn:

| Khâu | Số ngày TB | Tỷ trọng |
| :-- | --: | --: |
| Duyệt thanh toán | 0,43 | 3,4% |
| Người bán giao cho đơn vị vận chuyển | 2,80 | 22,3% |
| **Vận chuyển đến khách** | **9,33** | **74,3%** |

Đơn trễ mất 31,5 ngày so với 10,9 ngày của đơn đúng hẹn, và **86,2% chênh lệch đến từ khâu vận
chuyển**. Thời gian người bán xuất hàng gần như giống hệt nhau ở mọi vùng (2,68–2,88 ngày) trong khi
thời gian vận chuyển chênh 2,5 lần (Southeast 7,5 ngày so với North 19,3 ngày). Người bán không phải
vấn đề — vận chuyển đường dài mới là. Đây cũng là khâu duy nhất đang cải thiện: giảm từ ~13 ngày đầu
2018 xuống ~7 ngày vào tháng 8.

### 3.5 Khách hàng gần như không tự quay lại

Theo dõi cùng một tệp khách qua hai mốc cách nhau sáu tháng: trong 55.524 khách hoạt động ở kỳ đầu,
chỉ **1,2% phát sinh đơn hàng mới** trong sáu tháng tiếp theo. Dòng dịch chuyển vòng đời gần như một
chiều (Engaged → Cooling → Dormant), tỷ lệ hồi phục ở mọi trạng thái chỉ khoảng 1%.

---

## 4. Khuyến nghị hành động

**Ưu tiên 1 — Win-back nhóm Cooling (25.114 khách).** Đây là nhóm đã vượt ngưỡng cần can thiệp nhưng
chưa mất hẳn. Mô phỏng dựa trên các giá trị đo được (tỷ lệ tự quay lại nền 1,08%, AOV R$159,86) cho
một quy tắc quyết định đơn giản:

> **Cứ mỗi R$1,60 chi cho một khách thì cần thêm 1 điểm phần trăm uplift để hòa vốn.**

Kênh chi phí thấp (email, push — dưới R$1/khách) có lãi ở mọi mức uplift thực tế, nên triển khai
ngay. Ưu đãi trên R$5/khách cần uplift ≥3 điểm phần trăm — chưa được chứng minh, cần thử nghiệm A/B
test trước khi mở rộng. Dashboard có mô hình What-If tương tác và ma trận độ nhạy bao phủ toàn bộ
không gian quyết định chi phí × uplift.

**Ưu tiên 2 — Bảo vệ doanh thu nhóm At Risk bằng logistics.** Nhóm nắm 39,5% doanh thu đang nhận
trải nghiệm giao hàng tệ nhất. Vì điểm nghẽn đã được chứng minh là khâu vận chuyển chứ không phải
người bán, việc ưu tiên tuyến giao hàng cho khách giá trị cao sẽ trực tiếp bảo vệ doanh thu lõi.

**Ưu tiên 3 — Chuyển đổi nhóm Potential Loyalist.** Vì không tồn tại nhóm Champions, nhóm này (31%
khách hàng, 30,3% doanh thu, hoạt động gần đây nhất) là con đường thực tế duy nhất để xây dựng tầng
khách hàng trung thành.

**Không đầu tư quá mức vào nhóm Lost.** 26,3% khách hàng, 15,9% doanh thu, im lặng 424 ngày, tỷ lệ
tái kích hoạt ~0,7%. Chỉ nên tiếp cận trong các chiến dịch lớn theo mùa.

---

## 5. Dashboard

Báo cáo Power BI 5 trang. Tính năng tương tác: điều hướng giữa các trang, bộ lọc theo phân khúc,
drill-through sang danh sách khách hàng đã lọc, và tham số What-If điều khiển mô hình business case
theo thời gian thực.

| Trang | Mục đích |
| :-- | :-- |
| Executive Overview | Sức khỏe kinh doanh: doanh thu, khách hàng, AOV, CLV, xu hướng giữ chân, địa lý, cơ cấu thanh toán |
| Customer Segmentation | Năm phân khúc, mức độ tập trung doanh thu, danh mục sản phẩm, danh sách khách xuất được |
| Operations & Logistics | Hiệu suất giao hàng theo phân khúc và vùng, phân rã ba khâu, xu hướng |
| Win-back Business Case | Mô phỏng What-If với phân tích hòa vốn và ma trận độ nhạy chi phí × uplift |
| Customer List | Trang đích drill-through — danh sách đã lọc, xuất CSV cho chiến dịch |

![Executive Overview](powerbi/screenshots/01_executive_overview.png)
![Customer Segmentation](powerbi/screenshots/02_customer_segmentation.png)
![Operations & Logistics](powerbi/screenshots/03_operations_logistics.png)
![Win-back Business Case](powerbi/screenshots/04_business_case.png)
![Customer List](powerbi/screenshots/05_customer_list.png)

### Tính năng tương tác

**Mô phỏng What-If** — kéo thanh trượt chi phí và uplift để tính lại lãi ròng theo thời gian thực;
thẻ số đổi màu tại điểm hòa vốn, ma trận độ nhạy thể hiện toàn bộ không gian quyết định.

![Mô phỏng What-If](powerbi/screenshots/demo_whatif.gif)

**Drill-through** — chọn một phân khúc rồi mở danh sách khách hàng để có danh sách đã lọc, xuất được
ra CSV phục vụ chạy chiến dịch.

![Drill-through sang danh sách khách hàng](powerbi/screenshots/demo_drillthrough.gif)

---

## 6. Công nghệ sử dụng và các quyết định kỹ thuật

**Công nghệ:** PostgreSQL · Python (pandas, scikit-learn, statsmodels, SQLAlchemy) · Power BI

Các quyết định ảnh hưởng trực tiếp đến kết quả:

| Quyết định | Lý do |
| :-- | :-- |
| Định danh khách bằng `customer_unique_id` | `customer_id` được sinh mới theo từng đơn; dùng nó sẽ khiến mọi khách hàng trông như chỉ mua đúng một lần |
| Gộp payments về grain đơn hàng trước khi JOIN | JOIN trực tiếp payments với items làm doanh thu bị nhân bản (đã kiểm chứng: R$375,73 thành R$751,46 trên một đơn) |
| Hai bảng fact ở hai grain khác nhau | Grain đơn hàng cho RFM và doanh thu; grain sản phẩm cho phân tích danh mục và người bán |
| Chỉ phân tích đơn `delivered` | Đơn hủy và không giao được sẽ làm sai lệch giá trị Monetary |
| Snapshot date = ngày mua cuối + 1 ngày | Dùng ngày hiện tại sẽ khiến mọi khách bị xếp là đã ngừng mua nhiều năm |
| Log transform F và M, sau đó StandardScaler | F và M lệch phải nặng; MinMaxScaler sẽ để một khách R$13.664 nén toàn bộ phần còn lại |
| Giữ lại outlier, không loại bỏ | Khách chi tiêu cao là khách sỉ, không phải lỗi dữ liệu — loại bỏ là vứt đi doanh thu thật |
| Chọn K=5 dựa trên khả năng diễn giải | Silhouette score không phân biệt được từ K=3 trở đi; K=4 gộp chung nhóm giá trị cao còn hoạt động với nhóm giá trị cao đã nguội, vốn cần chiến lược trái ngược |
| Ngưỡng churn từ phân tích sống sót | Quy ước 90 ngày phân loại nhầm 45% khách sẽ quay lại |
| Dùng ngưỡng cố định cho phân tích dịch chuyển | Phân cụm lại từng kỳ sẽ tạo ra dịch chuyển giả khi ranh giới cụm thay đổi |

---

## 7. Cách tái lập

**Yêu cầu:** PostgreSQL, Python 3.10+, Power BI Desktop.

1. Tải [bộ dữ liệu Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) vào `data/raw/`.
2. Tạo database `olist_db`, sau đó chạy theo thứ tự:
   - `sql/01_bronze_schema.sql` — tạo bảng thô, rồi import các file CSV
   - `sql/02_gold_schema.sql` — tạo star schema
   - `sql/03_gold_schema_load.sql` — nạp dimension và fact
3. Tạo file `.env` ở thư mục gốc (đã được khai báo trong `.gitignore` nên thông tin đăng nhập không
   bao giờ bị commit):
   ```
   DB_USER=postgres
   DB_PASSWORD=mat_khau_cua_ban
   DB_HOST=localhost
   DB_PORT=5432
   DB_NAME=olist_db
   ```
4. Chạy `notebooks/01_eda_rfm_kmeans.ipynb` — ghi kết quả phân khúc vào `gold.fact_rfm_segments`.
5. Chạy các file SQL còn lại: `04_add_segment_to_dim.sql`, `05_add_region.sql`,
   `07_add_delivery_stages.sql`.
6. Kiểm tra bằng `sql/06_data_quality_checks.sql` — mọi kiểm tra phải trả về PASS.
7. Chạy `notebooks/02_advanced_analysis.ipynb` cho phân tích sống sót, dịch chuyển và business case.
8. Mở `powerbi/Olist_RFM_Dashboard.pbix`, cập nhật thông tin kết nối và refresh.
   Dùng **View → Reading view** để có đầy đủ tính năng tương tác trong Desktop.

---

## 8. Giới hạn và hướng phát triển

**Giới hạn dữ liệu**

- Không có dữ liệu chi phí marketing và giá vốn — CLV được đo theo doanh thu trên mỗi khách, không
  phải lợi nhuận, và không tính được chi phí thu hút khách hàng (CAC).
- Không có dữ liệu nhân khẩu học hay hành vi truy cập — phân khúc chỉ dựa trên hành vi mua.
- Dữ liệu kết thúc tháng 10/2018 — các khuyến nghị không thể kiểm chứng bằng kết quả thực tế.
- Năm 2016 chỉ có 329 đơn; các tháng đầu bị loại khỏi phân tích xu hướng vì mẫu quá nhỏ.

**Lưu ý về phương pháp**

- Với 97,8% khách chỉ mua một lần, Frequency gần như không có khả năng phân biệt. Các cụm thực chất
  được hình thành bởi Recency và Monetary.
- Tỷ lệ dịch chuyển vòng đời nhạy với ngưỡng churn (34,8% đến 50,8% trong khoảng P85–P95). Kết luận
  định tính đúng ở mọi ngưỡng, nhưng con số điểm không nên được trích dẫn như giá trị chính xác. Tỷ
  lệ tái kích hoạt không phụ thuộc ngưỡng (1,2%) được dùng ở mọi nơi cần một con số ổn định.
- Uplift trong business case là giả định, không phải số đo. Thiết kế A/B test trong
  `notebooks/02` mô tả cách kiểm chứng nó.

**Hướng phát triển**

- Mô hình dự đoán churn (logistic regression trên đặc điểm đơn hàng đầu tiên: điểm review, độ trễ
  giao hàng, danh mục, khu vực).
- Phân rã sâu hơn thời gian giao hàng bằng các mốc thời gian phía người bán để tách riêng độ trễ ở
  khâu bàn giao cho đơn vị vận chuyển.
- Chuyển các phép biến đổi SQL sang dbt để có kiểm thử và truy vết dòng dữ liệu.

---

## Cấu trúc thư mục

```
├── data/raw/               File CSV từ Kaggle — không đưa lên repo; tải theo hướng dẫn mục 7
├── sql/
│   ├── 01_bronze_schema.sql           Định nghĩa bảng thô
│   ├── 02_gold_schema.sql             Star schema (4 dim, 3 fact)
│   ├── 03_gold_schema_load.sql        Biến đổi Bronze → Gold
│   ├── 04–05, 07                      Nhãn phân khúc, vùng miền, phân rã khâu giao hàng
│   └── 06_data_quality_checks.sql     Kiểm tra đối chiếu (số dòng, khóa mồ côi, tính toàn vẹn PK)
├── notebooks/
│   ├── 01_eda_rfm_kmeans.ipynb        RFM, K-Means, đặc trưng phân khúc
│   └── 02_advanced_analysis.ipynb     Sống sót, dịch chuyển, business case, A/B design
├── powerbi/
│   ├── Olist_RFM_Dashboard.pbix
│   └── screenshots/                   Ảnh chụp các trang và GIF minh họa tương tác
├── business_analysis.md    Câu hỏi kinh doanh, số liệu nền tảng, định nghĩa KPI
├── README.md               Bản tiếng Anh
└── README_vi.md
```
