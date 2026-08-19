# Day 19 Lab — REFLECTION

Trong bài lab hôm nay, em đã so sánh 3 chế độ tìm kiếm trên 50 câu hỏi tiếng Việt:
**Keyword (BM25)**, **Semantic (vector)**, và **Hybrid (RRF k=60)**.

**Kết quả Precision@10:**
- Keyword (BM25): ~77% — mạnh khi query chính xác ("cloud", "database").
- Semantic (vector): ~73% — tốt với paraphrase nhưng yếu khi model English trên VN.
- **Hybrid: ~78%** — chiến thắng cả hai, đặc biệt ở query mixed (100%).

**Khi nào KHÔNG nên dùng hybrid:**
1. Query rất ngắn, exact term (tên lỗi, API) — BM25 đủ.
2. Corpus nhỏ (<100 docs) — overhead RRF không cần thiết.
3. Cần latency rất thấp (<5ms) — hybrid tính thêm vector search.

**Bài học:** Hybrid là default tốt nhất, nhưng cần đo trên data thật
trước khi quyết định. Không nên tin marketing mà phải đo performance.
