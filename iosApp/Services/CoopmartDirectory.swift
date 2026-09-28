import Foundation

public struct CoopmartStore: Hashable, Codable {
    public let name: String
    public let address: String
    public let phone: String
    public let lat: Double
    public let lng: Double
    public let keyTokens: [String]

    public init(name: String, address: String, phone: String, lat: Double, lng: Double, keyTokens: [String] = []) {
        self.name: name
        self.address: address
        self.phone: phone
        self.lat: lat
        self.lng: lng
        self.keyTokens: keyTokens
    }
}

public enum CoopmartDirectory {
    public static let stores: [CoopmartStore] = [
        CoopmartStore(
            name: "TRỤ SỞ CHÍNH SAIGON CO.OP",
            address: "199-205 Nguyễn Thái Học, Phường Cầu Ông Lãnh, Quận 1, Thành phố Hồ Chí Minh",
            phone: "(028) 38.360.143",
            lat: 10.764412,
            lng: 106.693425,
            keyTokens: ["TRỤ SỞ CHÍNH", "TRU SO CHINH", "TRỤ SỞ", "TRU SO", "VĂN PHÒNG TỔNG CÔNG TY", "VAN PHONG", "HQ", "UNIT_HQ", "SAIGON CO.OP", "SAIGON COOP", "TỔNG CÔNG TY"]
        ),
        CoopmartStore(
            name: "TRUNG TÂM PHÂN PHỐI SÓNG THẦN (KHO TỔNG)",
            address: "Đường số 6, KCN Sóng Thần 1, Phường Dĩ An, TP. Dĩ An, Bình Dương",
            phone: "(0274) 3.790.340",
            lat: 10.895311,
            lng: 106.748123,
            keyTokens: ["KHO TỔNG", "KHO TONG", "KHO SÓNG THẦN", "KHO SONG THAN", "SÓNG THẦN", "SONG THAN", "UNIT_KHO", "TRUNG TÂM PHÂN PHỐI", "TT PHAN PHOI", "KHO"]
        ),
        CoopmartStore(
            name: "TRUNG TÂM PHÂN PHỐI BÌNH DƯƠNG",
            address: "Đại lộ Bình Dương, Phường Thuận Giao, TP. Thuận An, Bình Dương",
            phone: "(0274) 3.788.112",
            lat: 10.945012,
            lng: 106.702045,
            keyTokens: ["KHO BÌNH DƯƠNG", "KHO BINH DUONG", "TTPP BÌNH DƯƠNG"]
        ),
        CoopmartStore(
            name: "IT TẬP TRUNG (PHÒNG CNTT & CĐS)",
            address: "199-205 Nguyễn Thái Học, Phường Cầu Ông Lãnh, Quận 1, Thành phố Hồ Chí Minh",
            phone: "(028) 38.360.143",
            lat: 10.764412,
            lng: 106.693425,
            keyTokens: ["IT TẬP TRUNG", "IT TAP TRUNG", "ITTT", "PCNTT", "PHÒNG CNTT", "PHONG CNTT", "CNTT", "DEPT_IT", "CÔNG NGHỆ"]
        ),
        CoopmartStore(
            name: "CHI NHÁNH QUẬN 1 (CO.OPMART CỐNG QUỲNH)",
            address: "189C Cống Quỳnh, Phường Cầu Ông Lãnh, Quận 1, Thành phố Hồ Chí Minh",
            phone: "(028) 39.250.725",
            lat: 10.7673055,
            lng: 106.6862896,
            keyTokens: ["CHI NHÁNH QUẬN 1", "CHI NHANH QUAN 1", "CN QUẬN 1", "CN QUAN 1", "UNIT_CN1"]
        ),
        CoopmartStore(
            name: "CO.OPMART CẦN GIỜ",
            address: "128 Đào Cử, Khu Phố Phong Thạnh, Xã Cần Giờ, Thành phố Hồ Chí Minh",
            phone: "(028) 37.861.748",
            lat: 10.4125992,
            lng: 106.9681186,
            keyTokens: ["CẦN GIỜ"]
        ),
        CoopmartStore(
            name: "CO.OPMART CHU VĂN AN",
            address: "241A Chu Văn An, Phường Bình Thạnh, Thành phố Hồ Chí Minh",
            phone: "(028) 35.166.800",
            lat: 10.8107365,
            lng: 106.7032152,
            keyTokens: ["CHU VĂN AN"]
        ),
        CoopmartStore(
            name: "CO.OPMART CỐNG QUỲNH",
            address: "189C  Cống Quỳnh, Phường Cầu Ông Lãnh, Thành phố Hồ Chí Minh",
            phone: "(028) 39.250.725",
            lat: 10.7673055,
            lng: 106.6862896,
            keyTokens: ["CỐNG QUỲNH"]
        ),
        CoopmartStore(
            name: "CO.OPMART HẬU GIANG",
            address: "188 Hậu Giang, Phường Bình Tây, Thành phố Hồ Chí Minh",
            phone: "(028) 39.600.255",
            lat: 10.749985,
            lng: 106.643181,
            keyTokens: ["HẬU GIANG"]
        ),
        CoopmartStore(
            name: "CO.OPMART HOÀ BÌNH",
            address: "175 Hòa Bình, Phường Phú Thạnh, Thành phố Hồ Chí Minh",
            phone: "(028) 39.613.970",
            lat: 10.7703038,
            lng: 106.629218,
            keyTokens: ["HOÀ BÌNH"]
        ),
        CoopmartStore(
            name: "CO.OPMART HÙNG VƯƠNG",
            address: "96 Hùng Vương, Phường An Đông, Thành phố Hồ Chí Minh",
            phone: "(028) 38.338.156",
            lat: 10.7595226,
            lng: 106.6714696,
            keyTokens: ["HÙNG VƯƠNG"]
        ),
        CoopmartStore(
            name: "CO.OPMART HUỲNH TẤN PHÁT",
            address: "1362 Đường Huỳnh Tấn Phát, Khu Phố 30, Phường Tân Mỹ, Thành phố Hồ Chí Minh",
            phone: "(028) 37.851.919",
            lat: 10.712241,
            lng: 106.7363604,
            keyTokens: ["HUỲNH TẤN PHÁT", "HTP"]
        ),
        CoopmartStore(
            name: "CO.OPMART NGUYỄN BÌNH",
            address: "18 Nguyễn Bình, Xã Nhà Bè, Thành phố Hồ Chí Minh",
            phone: "(028) 37.770.669",
            lat: 10.6738423,
            lng: 106.7359919,
            keyTokens: ["NGUYỄN BÌNH"]
        ),
        CoopmartStore(
            name: "CO.OPMART PHÚ LÂM",
            address: "06 Bà Hom, Phường Phú Lâm, Thành phố Hồ Chí Minh",
            phone: "(028) 37.514.799",
            lat: 10.754421,
            lng: 106.6336164,
            keyTokens: ["PHÚ LÂM"]
        ),
        CoopmartStore(
            name: "CO.OPMART PHÚ THỌ",
            address: "Lô1 - Lô2 , Khu A Chung Cư Phú Thọ, Phường  Phú Thọ, Thành phố Hồ Chí Minh",
            phone: "(028) 38.687.006",
            lat: 10.77083,
            lng: 106.6530245,
            keyTokens: ["PHÚ THỌ"]
        ),
        CoopmartStore(
            name: "CO.OPMART SCA CAO THẮNG",
            address: "181 Cao Thắng, Phường Hòa Hưng, Thành phố Hồ Chí Minh",
            phone: "(028) 36.221.251",
            lat: 10.7742527,
            lng: 106.674772,
            keyTokens: ["SCA CAO THẮNG"]
        ),
        CoopmartStore(
            name: "CO.OPMART TAM BÌNH",
            address: "0.01 Khu Chung Cư Cao Tầng Kết Hợp Tm-Dv Tại Lô Bc, Đường 4, K.P4, Phường Tam Bình, Thành phố Hồ Chí Minh",
            phone: "(028) 36.221.348",
            lat: 10.8641098,
            lng: 106.7343586,
            keyTokens: ["TAM BÌNH"]
        ),
        CoopmartStore(
            name: "CO.OPMART TUY LÝ VƯƠNG",
            address: "40 - 54  Tuy Lý Vương, Phường Phú Định, Thành phố Hồ Chí Minh",
            phone: "(028) 39.515.462",
            lat: 10.7441433,
            lng: 106.6551553,
            keyTokens: ["TUY LÝ VƯƠNG"]
        ),
        CoopmartStore(
            name: "CO.OPMART VĂN THÁNH",
            address: "561A Điện Biên Phủ, Phường Thạnh Mỹ Tây, Thành phố Hồ Chí Minh",
            phone: "(028) 35.121.068",
            lat: 10.7999678,
            lng: 106.7185699,
            keyTokens: ["VĂN THÁNH"]
        ),
        CoopmartStore(
            name: "CO.OPMART XA LỘ HÀ NỘI",
            address: "191 Quang Trung, Phường Tăng Nhơn Phú, Thành phố Hồ Chí Minh",
            phone: "(028) 38.307.233",
            lat: 10.8480014,
            lng: 106.7743068,
            keyTokens: ["XA LỘ HÀ NỘI", "XLHN"]
        ),
        CoopmartStore(
            name: "CO.OPMART PHẠM THẾ HIỂN",
            address: "2225 Phạm Thế Hiển, Phường Bình Đông, Thành phố Hồ Chí Minh",
            phone: "(028) 36.224.949",
            lat: 10.7332197,
            lng: 106.6438184,
            keyTokens: ["PHẠM THẾ HIỂN"]
        ),
        CoopmartStore(
            name: "CO.OPMART BÌNH TÂN",
            address: "TTTM Kiến Thành, Số 158 Đường 19, Phường An Lạc, Thành phố Hồ Chí Minh",
            phone: "(028) 37.626.702",
            lat: 10.7535972,
            lng: 106.6133909,
            keyTokens: ["BÌNH TÂN"]
        ),
        CoopmartStore(
            name: "CO.OPMART BÌNH TÂN 2",
            address: "819 Hương Lộ 2, Phường Bình Trị Đông, Thành phố Hồ Chí Minh",
            phone: "(028) 36.229.801",
            lat: 10.7651091,
            lng: 106.6013259,
            keyTokens: ["BÌNH TÂN 2"]
        ),
        CoopmartStore(
            name: "CO.OPMART CỦ CHI",
            address: "357 Phan Văn Khải, Ấp Thượng, Xã Củ Chi, Thành phố Hồ Chí Minh",
            phone: "028 37902221",
            lat: 10.9589961,
            lng: 106.5045037,
            keyTokens: ["CỦ CHI"]
        ),
        CoopmartStore(
            name: "CO.OPMART ĐỖ VĂN DẬY",
            address: "18 Đỗ Văn Dậy, Ấp 3, Xã Hóc Môn, Thành phố Hồ Chí Minh",
            phone: "(028) 37.100.602",
            lat: 10.8942086,
            lng: 106.5985385,
            keyTokens: ["ĐỖ VĂN DẬY"]
        ),
        CoopmartStore(
            name: "CO.OPMART QUANG TRUNG (FOODCOSA)",
            address: "340A Quang Trung, Phường Thông Tây Hội, Thành phố Hồ Chí Minh",
            phone: "(028) 39.966.477",
            lat: 10.8349689,
            lng: 106.6620909,
            keyTokens: ["QUANG TRUNG (FOODCOSA]", "QT")
        ),
        CoopmartStore(
            name: "CO.OPMART HIỆP THÀNH",
            address: "276 Nguyễn Ảnh Thủ, Phường Tân Thới Hiệp, Thành phố Hồ Chí Minh",
            phone: "(028) 37.172.262",
            lat: 10.8777967,
            lng: 106.6398595,
            keyTokens: ["HIỆP THÀNH"]
        ),
        CoopmartStore(
            name: "CO.OPMART HÓC MÔN",
            address: "Số 380 Đường Đặng Thúc Vịnh, Xã  Đông Thạnh, Thành phố Hồ Chí Minh",
            phone: "(028) 37.107.192",
            lat: 10.8891008,
            lng: 106.6066393,
            keyTokens: ["HÓC MÔN"]
        ),
        CoopmartStore(
            name: "CO.OPMART LÝ THƯỜNG KIỆT",
            address: "497 Hòa Hảo, Phường Diên Hồng, Thành phố Hồ Chí Minh",
            phone: "(028) 39.572.844",
            lat: 10.7598125,
            lng: 106.6614522,
            keyTokens: ["LÝ THƯỜNG KIỆT", "LY THUONG KIET", "LTK", "505"]
        ),
        CoopmartStore(
            name: "CO.OPMART NGUYỄN ẢNH THỦ",
            address: "167/2  Nguyễn Ảnh Thủ, Phường Trung Mỹ Tây, Thành phố Hồ Chí Minh",
            phone: "(028) 37.185.476",
            lat: 10.8573142,
            lng: 106.6089271,
            keyTokens: ["NGUYỄN ẢNH THỦ"]
        ),
        CoopmartStore(
            name: "CO.OPMART NGUYỄN ĐÌNH CHIỂU",
            address: "168 Nguyễn Đình Chiểu, Phường Xuân Hòa, Thành phố Hồ Chí Minh",
            phone: "(028) 39.301.456",
            lat: 10.7814923,
            lng: 106.6924141,
            keyTokens: ["NGUYỄN ĐÌNH CHIỂU"]
        ),
        CoopmartStore(
            name: "CO.OPMART NGUYỄN KIỆM",
            address: "571 - 573 Nguyễn Kiệm, Phường Đức Nhuận, Thành phố Hồ Chí Minh",
            phone: "(028) 39.972.472",
            lat: 10.8086624,
            lng: 106.6781238,
            keyTokens: ["NGUYỄN KIỆM"]
        ),
        CoopmartStore(
            name: "CO.OPMART NHIÊU LỘC",
            address: "Cao Ốc Screc, Đường Trường Sa, Phường Nhiêu Lộc, Thành phố Hồ Chí Minh",
            phone: "(028) 62.904.803",
            lat: 10.7864915,
            lng: 106.6755081,
            keyTokens: ["NHIÊU LỘC"]
        ),
        CoopmartStore(
            name: "CO.OPMART PHAN VĂN HỚN",
            address: "102 Đường Phan Văn Hớn, Phường Đông Hưng Thuận, Thành phố Hồ Chí Minh",
            phone: "(028) 38.155.483",
            lat: 10.8284764,
            lng: 106.6199905,
            keyTokens: ["PHAN VĂN HỚN"]
        ),
        CoopmartStore(
            name: "CO.OPMART PHAN VĂN TRỊ",
            address: "543/1 Phan Văn Trị, Phường Hạnh Thông, Thành phố Hồ Chí Minh",
            phone: "(028) 38.946.887",
            lat: 10.829894,
            lng: 106.682245,
            keyTokens: ["PHAN VĂN TRỊ"]
        ),
        CoopmartStore(
            name: "CO.OPMART RẠCH MIỄU",
            address: "48 Hoa Sứ, Phường Cầu Kiệu, Thành phố Hồ Chí Minh",
            phone: "(028) 35.171.368",
            lat: 10.7987623,
            lng: 106.6890619,
            keyTokens: ["RẠCH MIỄU"]
        ),
        CoopmartStore(
            name: "CO.OPMART THẮNG LỢI",
            address: "02 Trường Chinh, Phường Tây Thạnh, Thành Phố Hồ Chí Minh",
            phone: "(028) 36.227.600",
            lat: 10.8180007,
            lng: 106.6308026,
            keyTokens: ["THẮNG LỢI"]
        ),
        CoopmartStore(
            name: "CO.OPMART VĨNH LỘC B",
            address: "02 Khu Tái Định Cư Vĩnh Lộc B, Đường Số 8, Xã Tân Vĩnh Lộc, Huyện Bình Chánh",
            phone: "(028) 73.016.999",
            lat: 10.7705974,
            lng: 106.5660019,
            keyTokens: ["VĨNH LỘC B"]
        ),
        CoopmartStore(
            name: "CO.OPMART BÀ RỊA",
            address: "Số 6, Nguyễn Hữu Thọ, Khu Phố 2, Phường Bà Rịa, Thành phố Hồ Chí Minh",
            phone: "(0254) 3.739.359",
            lat: 10.4894835,
            lng: 107.1743041,
            keyTokens: ["BÀ RỊA"]
        ),
        CoopmartStore(
            name: "CO.OPMART BIÊN HÒA",
            address: "121  Phạm Văn Thuận, Phường Tam Hiệp, Tỉnh Đồng Nai",
            phone: "(0251) 3.949.988",
            lat: 10.9586596,
            lng: 106.8341573,
            keyTokens: ["BIÊN HÒA"]
        ),
        CoopmartStore(
            name: "CO.OPMART BÌNH DƯƠNG",
            address: "Đường 30/4, Phường Thủ Dầu Một, Thành phố Hồ Chí Minh",
            phone: "(0274) 3.818.655",
            lat: 10.9645131,
            lng: 106.6675335,
            keyTokens: ["BÌNH DƯƠNG", "BINH DUONG", "516"]
        ),
        CoopmartStore(
            name: "CO.OPMART BÌNH DƯƠNG 2",
            address: "Đường Phú Lợi, Phường Phú Lợi, Thành phố Hồ Chí Minh",
            phone: "(0274) 6.259.779",
            lat: 10.9842506,
            lng: 106.6669444,
            keyTokens: ["BÌNH DƯƠNG 2"]
        ),
        CoopmartStore(
            name: "CO.OPMART ĐỒNG XOÀI",
            address: "Khu TTTM, Đường Phú Riềng Đỏ,  Phường Bình Phước, Tỉnh Đồng Nai",
            phone: "(0271) 3.865.666",
            lat: 11.5329706,
            lng: 106.8972172,
            keyTokens: ["ĐỒNG XOÀI"]
        ),
        CoopmartStore(
            name: "CO.OPMART CHÂU THÀNH",
            address: "Đường 781, Khu Phố 3, Xã Châu Thành, Tỉnh Tây Ninh",
            phone: "(0276) 3.887.799",
            lat: 11.3102544,
            lng: 106.0279924,
            keyTokens: ["CHÂU THÀNH"]
        ),
        CoopmartStore(
            name: "CO.OPMART ĐỒNG PHÚ",
            address: "Đường CMT8 - Đt.741, Khu Phô Tân An, Xã Đồng Phú, Tỉnh Đồng Nai",
            phone: "(0271) 3.908.001",
            lat: 11.4453341,
            lng: 106.8694401,
            keyTokens: ["ĐỒNG PHÚ"]
        ),
        CoopmartStore(
            name: "CO.OPMART DƯƠNG MINH CHÂU",
            address: "Khu Phố 1, Xã Dương Minh Châu, Tỉnh Tây Ninh",
            phone: "(0276) 3 747.979",
            lat: 11.3807989,
            lng: 106.2291964,
            keyTokens: ["DƯƠNG MINH CHÂU"]
        ),
        CoopmartStore(
            name: "CO.OPMART GÒ DẦU",
            address: "Quốc Lộ 22B, Khu Phố Rạch Sơn, Phường Gò Dầu, Tỉnh Tây Ninh",
            phone: "(0276) 3.522.568",
            lat: 11.0894333,
            lng: 106.2646506,
            keyTokens: ["GÒ DẦU"]
        ),
        CoopmartStore(
            name: "CO.OPMART LAGI",
            address: "Đường Thống Nhất, Khu Phố 4, Phường La Gi, Tỉnh Lâm Đồng",
            phone: "(0252) 3.561.666",
            lat: 10.6708678,
            lng: 107.7601711,
            keyTokens: ["LAGI"]
        ),
        CoopmartStore(
            name: "CO.OPMART PHAN RÍ CỬA",
            address: "Thôn Minh Tân 2, Xã Phan Rí Cửa, Tỉnh Lâm Đồng",
            phone: "(0252) 3.909.099",
            lat: 11.1804493,
            lng: 108.5765815,
            keyTokens: ["PHAN RÍ CỬA"]
        ),
        CoopmartStore(
            name: "CO.OPMART PHAN THIẾT",
            address: "1A Nguyễn Tất Thành, Phường Phan Thiết, Tỉnh Lâm Đồng",
            phone: "(0252) 3.835.435",
            lat: 10.9298075,
            lng: 108.1055777,
            keyTokens: ["PHAN THIẾT"]
        ),
        CoopmartStore(
            name: "CO.OPMART PHƯỚC ĐÔNG",
            address: "KCN Phước Đông, Phường Gia Lộc Tỉnh Tây Ninh",
            phone: "(0276) 3.628.555",
            lat: 11.1356721,
            lng: 106.3140382,
            keyTokens: ["PHƯỚC ĐÔNG"]
        ),
        CoopmartStore(
            name: "CO.OPMART TÂN BIÊN",
            address: "Khu Phố 3, Nguyễn Văn Linh, Xã Tân Biên, Tỉnh Tây Ninh",
            phone: "(0276) 3.887.979",
            lat: 11.5353599,
            lng: 106.0072608,
            keyTokens: ["TÂN BIÊN"]
        ),
        CoopmartStore(
            name: "CO.OPMART TÂN CHÂU",
            address: "Lê Duẩn, Kp 2, Xã Tân Châu, TỉnhTây Ninh",
            phone: "(0276) 3.755.999",
            lat: 11.5536961,
            lng: 106.1628697,
            keyTokens: ["TÂN CHÂU"]
        ),
        CoopmartStore(
            name: "CO.OPMART TÂN THÀNH",
            address: "Số 1469 Đường Độc Lập, Phường Phú Mỹ, Thành phố Hồ Chí Minh",
            phone: "(0254) 3.924.611",
            lat: 10.5981489,
            lng: 107.0551982,
            keyTokens: ["TÂN THÀNH"]
        ),
        CoopmartStore(
            name: "CO.OPMART TÂY NINH",
            address: "576  Cách Mạng  Tháng 8, Phường Tân Ninh, Tỉnh Tây Ninh",
            phone: "(0276) 3.922.339",
            lat: 11.3079931,
            lng: 106.1087157,
            keyTokens: ["TÂY NINH"]
        ),
        CoopmartStore(
            name: "CO.OP MART TRẢNG BÀNG",
            address: "Khu Phố Lộc An,Phường Trảng Bàng, Tỉnh Tây Ninh",
            phone: "(0276) 3.890.949",
            lat: 11.0306675,
            lng: 106.3561291,
            keyTokens: ["CO.OP MART TRẢNG BÀNG"]
        ),
        CoopmartStore(
            name: "CO.OPMART VŨNG TÀU",
            address: "36 Nguyễn Thái Học, Phường Tam Thắng, Thành phố Hồ Chí Minh",
            phone: "(0254) 3.576.200",
            lat: 10.3669944,
            lng: 107.0855396,
            keyTokens: ["VŨNG TÀU"]
        ),
        CoopmartStore(
            name: "CO.OPMART BẾN LỨC",
            address: "61 Quốc Lộ 1A, Khu Phố 4, Xã Bến Lức, Tỉnh Tây Ninh",
            phone: "(0272) 3 630 998",
            lat: 10.6379133,
            lng: 106.4826334,
            keyTokens: ["BẾN LỨC"]
        ),
        CoopmartStore(
            name: "CO.OPMART BẾN TRE",
            address: "26A Trần Quốc Tuấn, Phường An Hội, Tỉnh Vĩnh Long",
            phone: "(0275) 3.511.322",
            lat: 10.2421318,
            lng: 106.3765343,
            keyTokens: ["BẾN TRE"]
        ),
        CoopmartStore(
            name: "CO.OPMART CAI LẬY",
            address: "Số 79 Đường 30/4, Khu Phố 2, Phường Mỹ Phước Tây, Tỉnh Đồng Tháp",
            phone: "(0273) 3.813.749",
            lat: 10.4081888,
            lng: 106.1197738,
            keyTokens: ["CAI LẬY"]
        ),
        CoopmartStore(
            name: "CO.OPMART CẦN GIUỘC",
            address: "Tuyến Tránh Ql50, Khu Phố Thanh Ba, Xã Cần Giuộc, Tỉnh Tây Ninh",
            phone: "(0272) 3.900.910",
            lat: 10.605496,
            lng: 106.6564151,
            keyTokens: ["CẦN GIUỘC"]
        ),
        CoopmartStore(
            name: "CO.OPMART CAO LÃNH",
            address: "01 Ngô Thời Nhậm, Phường Cao Lãnh, Tỉnh Đồng Tháp",
            phone: "(0277) 3.661.199",
            lat: 10.4595778,
            lng: 105.6406727,
            keyTokens: ["CAO LÃNH"]
        ),
        CoopmartStore(
            name: "CO.OPMART DUYÊN HẢI",
            address: "Đường Lý Thường Kiệt, Phường Duyên Hải, Tỉnh Vĩnh Long",
            phone: "(0294) 3.832.929",
            lat: 9.6364534,
            lng: 106.4971588,
            keyTokens: ["DUYÊN HẢI"]
        ),
        CoopmartStore(
            name: "CO.OPMART GÒ CÔNG",
            address: "Đường Trần Công Tường, Khu phố 11, Phường Gò Công, Tỉnh Đồng Tháp",
            phone: "(0273) 3.841.106",
            lat: 10.3547154,
            lng: 106.673095,
            keyTokens: ["GÒ CÔNG"]
        ),
        CoopmartStore(
            name: "CO.OPMART HỒNG NGỰ",
            address: "Khu Nhà Cao Ốc Kii, Phường Hồng Ngự, Tỉnh Đồng Tháp",
            phone: "(0277) 3.621.987",
            lat: 10.810206,
            lng: 105.3494864,
            keyTokens: ["HỒNG NGỰ"]
        ),
        CoopmartStore(
            name: "CO.OPMART LONG AN",
            address: "01 Mai Thị Tốt, Phường Long An, Tỉnh Tây Ninh",
            phone: "(0272) 3.526.878",
            lat: 10.534873,
            lng: 106.4112182,
            keyTokens: ["LONG AN"]
        ),
        CoopmartStore(
            name: "CO.OPMART MỸ THO",
            address: "35 Ấp Bắc, Phường Đạo Thạnh, Tỉnh Đồng Tháp",
            phone: "(0273) 3.867.308",
            lat: 10.3731245,
            lng: 106.3476762,
            keyTokens: ["MỸ THO"]
        ),
        CoopmartStore(
            name: "CO.OPMART SA ĐÉC",
            address: "371 Đường Nguyễn Sinh Sắc, Khóm 2, Phường Sa Đéc, Tỉnh Đồng Tháp",
            phone: "(0277) 3.889.388",
            lat: 10.289894,
            lng: 105.7583303,
            keyTokens: ["SA ĐÉC"]
        ),
        CoopmartStore(
            name: "CO.OPMART THÁP MƯỜI",
            address: "Đường Hùng Vương,Xã Tháp Mười, Tỉnh Đồng Tháp",
            phone: "(0277) 3.663.399",
            lat: 10.5209141,
            lng: 105.8485441,
            keyTokens: ["THÁP MƯỜI"]
        ),
        CoopmartStore(
            name: "CO.OPMART TIỂU CẦN",
            address: "Khóm 2, Thị Trấn Tiểu Cần, Xã Tiểu Cần, Tỉnh Vĩnh Long",
            phone: "(0294) 3.900.003",
            lat: 9.8227224,
            lng: 106.195973,
            keyTokens: ["TIỂU CẦN"]
        ),
        CoopmartStore(
            name: "CO.OPMART TRÀ VINH",
            address: "Nguyễn Đáng, Khóm 11, Phường Trà Vinh, Tỉnh Vĩnh Long",
            phone: "(0294) 3.740.707",
            lat: 9.9240649,
            lng: 106.340527,
            keyTokens: ["TRÀ VINH"]
        ),
        CoopmartStore(
            name: "CO.OPMART VĨNH LONG",
            address: "26 Đường 3/2, Phường Long Châu, Tỉnh Vĩnh Long",
            phone: "(0270) 3.836.713",
            lat: 10.2547696,
            lng: 105.9709564,
            keyTokens: ["VĨNH LONG"]
        ),
        CoopmartStore(
            name: "CO.OPMART CÁI BÈ",
            address: "Khu 2, Xã Cái Bè, Tỉnh Đồng Tháp",
            phone: "(0273) 3.922.779",
            lat: 10.3346805,
            lng: 106.0316555,
            keyTokens: ["CÁI BÈ"]
        ),
        CoopmartStore(
            name: "CO.OPMART BẠC LIÊU",
            address: "07 Trần Huỳnh, Phường Bạc Liêu, Tỉnh Cà Mau",
            phone: "(0291) 3.719.999",
            lat: 9.2925559,
            lng: 105.7161615,
            keyTokens: ["BẠC LIÊU"]
        ),
        CoopmartStore(
            name: "CO.OPMART BÌNH THỦY",
            address: "35-37 Cách Mạng Tháng 8, Phường Bình Thủy, Thành phố Cần Thơ",
            phone: "(0292) 3.907.007",
            lat: 10.0539989,
            lng: 105.7712237,
            keyTokens: ["BÌNH THỦY"]
        ),
        CoopmartStore(
            name: "CO.OPMART CHỢ MỚI",
            address: "Đường Tỉnh 942, Ấp Long Hòa, Xã Chợ Mới, Tỉnh An Giang",
            phone: "(0296) 3.662.987",
            lat: 10.5487595,
            lng: 105.4160825,
            keyTokens: ["CHỢ MỚI"]
        ),
        CoopmartStore(
            name: "CO.OPMART CÀ MAU",
            address: "09 Trần Hưng Đạo, Phường Tân Thành, Tỉnh Cà Mau",
            phone: "(0290) 3.656.999",
            lat: 9.178391,
            lng: 105.1548922,
            keyTokens: ["CÀ MAU"]
        ),
        CoopmartStore(
            name: "CO.OPMART CẦN THƠ",
            address: "01 Đại Lộ Hòa Bình, Phường Ninh Kiều, Thành Phố Cần Thơ",
            phone: "(0292) 3.763.585",
            lat: 10.0342006,
            lng: 105.7860641,
            keyTokens: ["CẦN THƠ", "CAN THO", "NINH KIỀU", "113"]
        ),
        CoopmartStore(
            name: "CO.OPMART CHÂU ĐỐC",
            address: "Tổ 21, Khóm Châu Quới 3, Phường Châu Đốc, Tỉnh An Giang",
            phone: "(0296) 3.566.909",
            lat: 10.7072291,
            lng: 105.1245103,
            keyTokens: ["CHÂU ĐỐC"]
        ),
        CoopmartStore(
            name: "CO.OPMART HÀ TIÊN",
            address: "Số 20, Đường Mạc Công Du, Khu Phố 1 Đông Hồ, Phường Hà Tiên, Tỉnh An Giang",
            phone: "(0297) 3.951.939",
            lat: 10.383789,
            lng: 104.4886655,
            keyTokens: ["HÀ TIÊN"]
        ),
        CoopmartStore(
            name: "CO.OPMART  KIÊN GIANG",
            address: "1332 Nguyễn Trung Trực, Phường Rạch Giá, Tỉnh An Giang",
            phone: "(0297) 3.896.666",
            lat: 9.959251,
            lng: 105.1183845,
            keyTokens: ["KIÊN GIANG"]
        ),
        CoopmartStore(
            name: "CO.OPMART LONG XUYÊN",
            address: "12 Nguyễn Huệ, Phường Long xuyên, Tỉnh An Giang",
            phone: "(0296) 3.944.001",
            lat: 10.3818459,
            lng: 105.4402693,
            keyTokens: ["LONG XUYÊN"]
        ),
        CoopmartStore(
            name: "CO.OPMART NGÃ BẢY HẬU GIANG",
            address: "Khu Vực 3, Phường Ngã Bảy, Thành phố Cần Thơ",
            phone: "(0293) 3.962.900",
            lat: 9.8125404,
            lng: 105.8209536,
            keyTokens: ["NGÃ BẢY HẬU GIANG"]
        ),
        CoopmartStore(
            name: "CO.OPMART RẠCH GIÁ",
            address: "Khu TTTM Tổng hợp 16ha, Phường Rạch Giá, Tỉnh An Giang",
            phone: "(0297) 3.947.881",
            lat: 10.0092644,
            lng: 105.0793225,
            keyTokens: ["RẠCH GIÁ"]
        ),
        CoopmartStore(
            name: "CO.OPMART SÓC TRĂNG",
            address: "Số 6 Hùng Vương, Phường Sóc Trăng, Thành phố Cần Thơ",
            phone: "(0299) 3.640.130",
            lat: 9.6127742,
            lng: 105.969505,
            keyTokens: ["SÓC TRĂNG"]
        ),
        CoopmartStore(
            name: "CO.OPMART  TÂN CHÂU (AG)",
            address: "Khóm Long Thạnh D, Phường Tân Châu, Tỉnh An Giang",
            phone: "(0296) 3.596.400",
            lat: 10.7948934,
            lng: 105.2415432,
            keyTokens: ["TÂN CHÂU (AG]")
        ),
        CoopmartStore(
            name: "CO.OPMART THỐT NỐT",
            address: "Quốc Lộ 91, Khu Vực Phụng Thạnh 1, Phường Thuận Hưng, Thành phố Cần Thơ",
            phone: "(0292) 3.851.144",
            lat: 10.2696374,
            lng: 105.5361213,
            keyTokens: ["THỐT NỐT"]
        ),
        CoopmartStore(
            name: "CO.OPMART VỊ THANH",
            address: "319 Trần Hưng Đạo, Phường Vị Thanh, Thành phố Cần Thơ",
            phone: "(0293) 3.581.688",
            lat: 9.78204,
            lng: 105.4670995,
            keyTokens: ["VỊ THANH"]
        ),
        CoopmartStore(
            name: "CO.OPMART AN NHƠN",
            address: "TTTM Hoàng Vũ Plaza, Quốc Lộ 1A, Phường Bình Định, Tỉnh Gia Lai",
            phone: "(0256) 3.635.677",
            lat: 13.8901428,
            lng: 109.1154889,
            keyTokens: ["AN NHƠN"]
        ),
        CoopmartStore(
            name: "CO.OPMART CAM RANH",
            address: "2038 Đại Lộ Hùng Vương, Phường Cam Ranh, Tỉnh Khánh Hòa",
            phone: "(0258) 3.855.679",
            lat: 11.9178227,
            lng: 109.1455355,
            keyTokens: ["CAM RANH"]
        ),
        CoopmartStore(
            name: "CO.OPMART  ĐÀ NẴNG",
            address: "478 Điện Biên Phủ, Phường Thanh Khê, Thành phố Đà Nẵng",
            phone: "(0236) 3.711.999",
            lat: 16.0665299,
            lng: 108.186957,
            keyTokens: ["ĐÀ NẴNG"]
        ),
        CoopmartStore(
            name: "CO.OPMART ĐỨC PHỔ",
            address: "Tổ dân phố Vĩnh Bình, Phường Đức Phổ, Tỉnh Quảng Ngãi",
            phone: "(0255) 3.888.675",
            lat: 14.819187,
            lng: 108.9529647,
            keyTokens: ["ĐỨC PHỔ"]
        ),
        CoopmartStore(
            name: "CO.OPMART HUẾ",
            address: "TTTM Trường Tiền Plaza - Số 6 Trần Hưng Đạo, Phường Phú Xuân, Thành phố Huế",
            phone: "(0234) 3.572.003",
            lat: 16.4710056,
            lng: 107.5876581,
            keyTokens: ["HUẾ"]
        ),
        CoopmartStore(
            name: "CO.OPMART NHA TRANG",
            address: "02 Lê Hồng Phong, Phường Nam Nha Trang, Tỉnh Khánh Hòa",
            phone: "(0258) 3.875.777",
            lat: 12.2427916,
            lng: 109.1821128,
            keyTokens: ["NHA TRANG"]
        ),
        CoopmartStore(
            name: "CO.OPMART  QUẢNG BÌNH",
            address: "Số 7 Đường  23-8, Phường Đồng Hới, Tỉnh Quảng Trị",
            phone: "(0232) 3.897.999",
            lat: 17.4616863,
            lng: 106.6182328,
            keyTokens: ["QUẢNG BÌNH"]
        ),
        CoopmartStore(
            name: "CO.OPMART QUẢNG NGÃI",
            address: "Hẻm 242 Nguyễn Nghiêm, Phường Cẩm Thành, Tỉnh Quảng Ngãi",
            phone: "(0255) 3.725.555",
            lat: 15.1212442,
            lng: 108.8066976,
            keyTokens: ["QUẢNG NGÃI"]
        ),
        CoopmartStore(
            name: "CO.OPMART  QUẢNG TRỊ",
            address: "02 Trần Hưng Đạo, Phường Đông Hà, Tỉnh Quảng Trị",
            phone: "(0233) 3.666.999",
            lat: 16.8227755,
            lng: 107.0989306,
            keyTokens: ["QUẢNG TRỊ"]
        ),
        CoopmartStore(
            name: "CO.OPMART QUY NHƠN",
            address: "07 Lê Duẩn, Phường Quy Nhơn, Tỉnh Gia Lai",
            phone: "(0256) 3.520.744",
            lat: 13.7675591,
            lng: 109.2220088,
            keyTokens: ["QUY NHƠN"]
        ),
        CoopmartStore(
            name: "CO.OPMART SƠN TRÀ",
            address: "Lô C2, Khu Công Nghiệp Dịch Vụ Thủy Sản Đà Nẵng, Đường Bình Than, Phường Sơn Trà, Thành phố Đà Nẵng",
            phone: "(0236) 3 925 333",
            lat: 16.0941881,
            lng: 108.2424746,
            keyTokens: ["SƠN TRÀ"]
        ),
        CoopmartStore(
            name: "CO.OPMART TAM KỲ",
            address: "07 Phan Chu Trinh, Phường Tam Kỳ, Thành phố Đà Nẵng",
            phone: "(0235) 2.220.230",
            lat: 15.5729589,
            lng: 108.4838371,
            keyTokens: ["TAM KỲ"]
        ),
        CoopmartStore(
            name: "CO.OPMART THANH HÀ",
            address: "TTTM Chợ Thanh Hà, Đường Trần  Phú, Phường Phan Rang, Tỉnh Khánh Hoà",
            phone: "(0259) 3.826.600",
            lat: 11.5755036,
            lng: 108.9886015,
            keyTokens: ["THANH HÀ"]
        ),
        CoopmartStore(
            name: "CO.OPMART  TUY HÒA",
            address: "Ô Phố 8B, Khu Dân Dụng Duy Tân, Phường Tuy Hòa, Tỉnh Đắk Lắk",
            phone: "(0257) 3.818.161",
            lat: 13.0886322,
            lng: 109.3096263,
            keyTokens: ["TUY HÒA"]
        ),
        CoopmartStore(
            name: "CO.OPMART BẢO LỘC",
            address: "Tháp Nước Đường Trần Phú,  Phường Bảo Lộc, Tỉnh Lâm Đồng",
            phone: "(0263) 3.710.610",
            lat: 11.5440511,
            lng: 107.8026111,
            keyTokens: ["BẢO LỘC"]
        ),
        CoopmartStore(
            name: "CO.OPMART BUÔN HỒ",
            address: "464 Hùng Vương, Phường Buôn Hồ, Tỉnh Đắk Lắk",
            phone: "(0262) 3.818.180",
            lat: 12.9155403,
            lng: 108.2649677,
            keyTokens: ["BUÔN HỒ"]
        ),
        CoopmartStore(
            name: "CO.OPMART BUÔN MÊ THUỘT",
            address: "71 Nguyễn Tất Thành, Phường Tân An, Tỉnh Đắk Lắk",
            phone: "(0262) 3.957.988",
            lat: 12.6921624,
            lng: 108.0620401,
            keyTokens: ["BUÔN MÊ THUỘT"]
        ),
        CoopmartStore(
            name: "CO.OPMART CHƯ SÊ",
            address: "912, Hùng Vương, Tổ dân phố 4, Xã Chư Sê, Tỉnh Gia Lai",
            phone: "(0269) 3.886.111",
            lat: 13.6908766,
            lng: 108.0784664,
            keyTokens: ["CHƯ SÊ"]
        ),
        CoopmartStore(
            name: "CO.OPMART CƯ M’GAR",
            address: "Thửa Đất 11, Tờ Bản Đồ Số 31, Tổ Dân Phố 2 Đường Hùng Vương, Xã Quảng Phú, Tỉnh Đắk Lắk",
            phone: "(0262) 3.510.139",
            lat: 12.8228849,
            lng: 108.0773763,
            keyTokens: ["CƯ M’GAR"]
        ),
        CoopmartStore(
            name: "CO.OPMART ĐĂK NÔNG",
            address: "Đường Huỳnh Thúc Kháng, Tổ Dân Phố 1, Phường Bắc Gia Nghĩa, Tỉnh Lâm Đồng",
            phone: "(0261) 3.555.553",
            lat: 12.0034771,
            lng: 107.6855533,
            keyTokens: ["ĐĂK NÔNG"]
        ),
        CoopmartStore(
            name: "CO.OPMART KON TUM",
            address: "205B Lê Hồng Phong, Phường Kon Tum, Tỉnh Quảng Ngãi",
            phone: "(0260) 3.838.789",
            lat: 14.3548734,
            lng: 108.0022793,
            keyTokens: ["KON TUM"]
        ),
        CoopmartStore(
            name: "CO.OPMART  PLEIKU",
            address: "21 Cách Mạng Tháng 8, Phường Pleiku, Tỉnh Gia Lai",
            phone: "(0269) 2.222.400",
            lat: 13.987215,
            lng: 108.008356,
            keyTokens: ["PLEIKU"]
        ),
        CoopmartStore(
            name: "CO.OPMART PRO VŨ YÊN",
            address: "Khu B1, Vũ Yên - Tòa nhà Vincom Mega Mall Vũ Yên, Phường Thủy Nguyên, Hải Phòng",
            phone: "0911 893 729",
            lat: 20.878114,
            lng: 106.7176327,
            keyTokens: ["PRO VŨ YÊN"]
        ),
        CoopmartStore(
            name: "CO.OP BẮC GIANG",
            address: "51 Nguyễn Văn Cừ, Phường Bắc Giang, Tỉnh Bắc Ninh",
            phone: "(0204) 3.549.999",
            lat: 21.277137,
            lng: 106.195281,
            keyTokens: ["CO.OP BẮC GIANG"]
        ),
        CoopmartStore(
            name: "CO.OP HÀ ĐÔNG",
            address: "Tầng 1, Tòa Nhà Ct6 Xa La, Số 339 Quốc Lộ 70B, Cầu Bươu, Phường Kiến Hưng, Thành phố Hà Nội",
            phone: "(024) 3.201.2830",
            lat: 20.9606462,
            lng: 105.8005846,
            keyTokens: ["CO.OP HÀ ĐÔNG"]
        ),
        CoopmartStore(
            name: "CO.OPMART THỐNG NHẤT",
            address: "Tầng 1-2, Khối A1, Khu căn hộ Bcons City, Đường Thống Nhất, Phường Đông Hòa, Tp Ho Chi Minh",
            phone: "091 108 65 29",
            lat: 10.8930369,
            lng: 106.7935501,
            keyTokens: ["THỐNG NHẤT", "THONG NHAT", "BCONS", "BCONS CITY", "578"]
        ),
        CoopmartStore(
            name: "CO.OP HÀ NỘI",
            address: "Km Số 10, Đường Nguyễn Trãi, Phường Hà Đông, Thành phố Hà Nội",
            phone: "(024) 6.285.3939",
            lat: 20.9827185,
            lng: 105.7904626,
            keyTokens: ["CO.OP HÀ NỘI"]
        ),
        CoopmartStore(
            name: "CO.OPMART HÀ TĨNH",
            address: "02 Phan Đình Phùng, Phường Thành Sen, Tỉnh Hà Tĩnh",
            phone: "(0239) 3.896.555",
            lat: 18.3382367,
            lng: 105.8968403,
            keyTokens: ["HÀ TĨNH"]
        ),
        CoopmartStore(
            name: "CO.OPMART HẢI PHÒNG",
            address: "TTTM Cát Bi Plaza, 01 Lê Hồng Phong, Phường Ngô Quyền, Thành phố Hải Phòng",
            phone: "(0225) 3.833.789",
            lat: 20.8607367,
            lng: 106.6969764,
            keyTokens: ["HẢI PHÒNG"]
        ),
        CoopmartStore(
            name: "CO.OPMART SCA GOLDENSILK",
            address: "Tầng Hầm, Tòa Tháp C, Khu Đô Thị Mới Kim Văn Kim Lũ, Phường Định Công, Thành phố Hà Nội",
            phone: "(024) 3.202.2130",
            lat: 20.9729158,
            lng: 105.8200527,
            keyTokens: ["SCA GOLDENSILK"]
        ),
        CoopmartStore(
            name: "CO.OPMART SCA GOLDSILK",
            address: "Tầng Trệt Khu Phức Hợp Thương Mại Nhà Ở Goldsilk, Số 430, Phố Cầu Am,Phường Hà Đông, Thành phố Hà Nội",
            phone: "0911.807.875",
            lat: 20.9768063,
            lng: 105.7755109,
            keyTokens: ["SCA GOLDSILK"]
        ),
        CoopmartStore(
            name: "CO.OPMART SCA LONG BIÊN",
            address: "Tầng 2,  Trung Tâm Thương Mại Mipec Riverside, Số 2,  Phố Long Biên II,  Phường Bồ Đề, Thành phố Hà Nội",
            phone: "(024) 3.202.2140",
            lat: 21.0455427,
            lng: 105.8662143,
            keyTokens: ["SCA LONG BIÊN"]
        ),
        CoopmartStore(
            name: "CO.OPMART SCA VICTORIA",
            address: "Tầng Trệt Tòa Nhà V2, V3 - Văn Phú Victoria - Ct9, Khu Đô Thị Mới Văn Phú, Phường Kiến Hưng, Thành phố Hà Nội",
            phone: "(024) 3.202.2113",
            lat: 20.9591916,
            lng: 105.7679905,
            keyTokens: ["SCA VICTORIA"]
        ),
        CoopmartStore(
            name: "CO.OPMART THANH HÓA",
            address: "TTTM Hiền Đức, Đường Phan Chu Trinh, Phường Hạc Thành, Tỉnh Thanh Hóa",
            phone: "(0237) 8.999.333",
            lat: 19.8122999,
            lng: 105.7738724,
            keyTokens: ["THANH HÓA"]
        ),
        CoopmartStore(
            name: "CO.OPMART VIỆT TRÌ",
            address: "1606A Đường Hùng Vương, Phường Việt Trì, Tỉnh Phú Thọ",
            phone: "(0210) 3.992.222",
            lat: 21.3217571,
            lng: 105.3859616,
            keyTokens: ["VIỆT TRÌ"]
        ),
        CoopmartStore(
            name: "CO.OPMART VĨNH PHÚC",
            address: "TTTM Soiva Plaza, Đường Mê Linh, Phường Vĩnh Phúc, Tỉnh Phú Thọ",
            phone: "(0211) 3.696.442",
            lat: 21.3129433,
            lng: 105.614404,
            keyTokens: ["VĨNH PHÚC"]
        ),
        CoopmartStore(
            name: "CO.OPXTRA TÂN PHONG",
            address: "TTTM SC VivoCity, 1058 Nguyễn Văn Linh, Phường Tân Phong, Quận 7, Thành phố Hồ Chí Minh",
            phone: "(028) 37.760.666",
            lat: 10.730335,
            lng: 106.702951,
            keyTokens: ["TÂN PHONG", "VIVOCITY", "SC VIVOCITY", "COOPXTRA TÂN PHONG", "COOPXTRA TAN PHONG"]
        ),
        CoopmartStore(
            name: "CO.OPXTRA LINH TRUNG",
            address: "934 Quốc Lộ 1A, Phường Linh Trung, Thành phố Thủ Đức, Thành phố Hồ Chí Minh",
            phone: "(028) 37.243.234",
            lat: 10.869812,
            lng: 106.776625,
            keyTokens: ["LINH TRUNG", "COOPXTRA LINH TRUNG"]
        ),
        CoopmartStore(
            name: "CO.OPXTRA VẠN HẠNH",
            address: "TTTM Vạn Hạnh Mall, 11 Sư Vạn Hạnh, Phường 12, Quận 10, Thành phố Hồ Chí Minh",
            phone: "(028) 38.623.636",
            lat: 10.771214,
            lng: 106.669528,
            keyTokens: ["VẠN HẠNH", "VAN HANH MALL", "COOPXTRA VẠN HẠNH", "VẠN HẠNH MALL"]
        ),
        CoopmartStore(
            name: "CO.OPXTRA THOẠI NGỌC HẦU",
            address: "102 Thoại Ngọc Hầu, Phường Phú Thạnh, Quận Tân Phú, Thành phố Hồ Chí Minh",
            phone: "(028) 39.733.888",
            lat: 10.778841,
            lng: 106.634621,
            keyTokens: ["THOẠI NGỌC HẦU", "TNH", "COOPXTRA THOẠI NGỌC HẦU"]
        ),
        CoopmartStore(
            name: "CO.OPXTRA TẠ QUANG BỬU",
            address: "332 Tạ Quang Bửu, Phường 5, Quận 8, Thành phố Hồ Chí Minh",
            phone: "(028) 38.502.888",
            lat: 10.738125,
            lng: 106.671234,
            keyTokens: ["TẠ QUANG BỬU", "TQB", "COOPXTRA TẠ QUANG BỬU"]
        ),
        CoopmartStore(
            name: "SENSE CITY CẦN THƠ",
            address: "01 Đại lộ Hòa Bình, Phường Tân An, Quận Ninh Kiều, Thành phố Cần Thơ",
            phone: "(0292) 3.688.888",
            lat: 10.035124,
            lng: 105.786542,
            keyTokens: ["SENSE CITY CẦN THƠ", "SENSE CẦN THƠ", "SENSE CITY CAN THO"]
        ),
        CoopmartStore(
            name: "SENSE CITY CÀ MAU",
            address: "09 Trần Hưng Đạo, Phường 5, Thành phố Cà Mau, Tỉnh Cà Mau",
            phone: "(0290) 3.555.555",
            lat: 9.176421,
            lng: 105.150821,
            keyTokens: ["SENSE CITY CÀ MAU", "SENSE CÀ MAU", "SENSE CITY CA MAU"]
        ),
        CoopmartStore(
            name: "SENSE CITY BẾN TRE",
            address: "26A Trần Quốc Tuấn, Phường 4, Thành phố Bến Tre, Tỉnh Bến Tre",
            phone: "(0275) 3.822.888",
            lat: 10.238241,
            lng: 106.377615,
            keyTokens: ["SENSE CITY BẾN TRE", "SENSE BẾN TRE", "SENSE CITY BEN TRE"]
        ),
        CoopmartStore(
            name: "SENSE CITY PHẠM VĂN ĐỒNG",
            address: "TTTM Gigamall, 240-242 Phạm Văn Đồng, Phường Hiệp Bình Chánh, Thành phố Thủ Đức, Thành phố Hồ Chí Minh",
            phone: "(028) 7108 0888",
            lat: 10.827732,
            lng: 106.721415,
            keyTokens: ["SENSE CITY PHẠM VĂN ĐỒNG", "GIGAMALL", "SENSE GIGAMALL", "SENSE PHẠM VĂN ĐỒNG"]
        )
    ]

    public static func normalize(_ input: String) -> String {
        let str = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let map: [Character: Character] = [
            "à": "a", "á": "a", "ả": "a", "ã": "a", "ạ": "a",
            "ă": "a", "ằ": "a", "ắ": "a", "ẳ": "a", "ẵ": "a", "ặ": "a",
            "â": "a", "ầ": "a", "ấ": "a", "ẩ": "a", "ẫ": "a", "ậ": "a",
            "đ": "d",
            "è": "e", "é": "e", "ẻ": "e", "ẽ": "e", "ẹ": "e",
            "ê": "e", "ề": "e", "ế": "e", "ể": "e", "ễ": "e", "ệ": "e",
            "ì": "i", "í": "i", "ỉ": "i", "ĩ": "i", "ị": "i",
            "ò": "o", "ó": "o", "ỏ": "o", "õ": "o", "ọ": "o",
            "ô": "o", "ồ": "o", "ố": "o", "ổ": "o", "ỗ": "o", "ộ": "o",
            "ơ": "o", "ờ": "o", "ớ": "o", "ở": "o", "ỡ": "o", "ợ": "o",
            "ù": "u", "ú": "u", "ủ": "u", "ũ": "u", "ụ": "u",
            "ư": "u", "ừ": "u", "ứ": "u", "ử": "u", "ữ": "u", "ự": "u",
            "ỳ": "y", "ý": "y", "ỷ": "y", "ỹ": "y", "ỵ": "y"
        ]
        var res = ""
        for ch in str {
            res.append(map[ch] ?? ch)
        }
        res = res.replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
        return res.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func extractCoreKeyword(_ normalized: String) -> String {
        var s = " \(normalized) "
        let stopWords = [
            "sieu thi coopmart", "sieu thi co opmart", "sieu thi coop", "sieu thi co op",
            "tttm sense city", "trung tam thuong mai sense city", "tttm sense",
            "coopxtra", "co opxtra", "co.opxtra", "xtra",
            "sense city", "sensecity", "sense market", "sensemarket",
            "finelife", "fine life",
            "coop food", "co.op food", "coopfood",
            "coop smile", "co.op smile", "coopsmile",
            "co opmart", "coopmart", "co op", "coop", "sieu thi", "chi nhanh", "st", "cn", "tttm"
        ]
        for w in stopWords {
            s = s.replacingOccurrences(of: " \(w) ", with: " ")
        }
        return s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func getStoreBrand(_ name: String) -> String {
        let norm = normalize(name)
        if norm.contains("sense city") || norm.contains("sense") {
            return "SENSE_CITY"
        } else if norm.contains("coopxtra") || norm.contains("co opxtra") || norm.contains("xtra") {
            return "XTRA"
        } else {
            return "COOPMART"
        }
    }

    public static func resolveLocation(_ query: String?) -> CoopmartStore? {
        return resolve(query)
    }

    public static func resolve(_ unitName: String?) -> CoopmartStore? {
        guard let unitName = unitName, !unitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        var cleaned = unitName.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "^\\s*\\[?[0-9]+\\]?\\s*[-_:–.]\\s*", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "^\\s*\\[[^\]]+\\]\\s*", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "(?i)^(don vi|chi nhanh|st|kho|van phong)\\s*:\\s*", with: "", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        let normInput = normalize(cleaned)
        let coreInput = extractCoreKeyword(normInput)
        if coreInput.isEmpty && normInput.isEmpty { return nil }

        let officePrefixes = ["phong ", "ban ", "khoi ", "to ", "van phong ", "trung tam dieu hanh"]
        let hasStoreKeyword = normInput.contains("coop") || normInput.contains("co op") ||
                              normInput.contains("sieu thi") || normInput.contains("sense") ||
                              normInput.contains("xtra") || normInput.contains("mart") ||
                              normInput.contains("st ") || normInput.contains("cn ") ||
                              normInput.contains("kho") || normInput.contains("tru so") ||
                              normInput.contains("it") || normInput.contains("cntt")
        if !hasStoreKeyword && officePrefixes.contains(where: { normInput.hasPrefix($0) || normInput.contains(" \($0)") }) {
            return nil
        }

        var desiredBrand: String? = nil
        if normInput.contains("sense city") || normInput.contains("sensecity") || normInput.contains("sense") {
            desiredBrand = "SENSE_CITY"
        } else if normInput.contains("coopxtra") || normInput.contains("co opxtra") || normInput.contains("xtra") {
            desiredBrand = "XTRA"
        } else if hasStoreKeyword {
            desiredBrand = "COOPMART"
        }

        let targetPool = desiredBrand != nil ? stores.filter { getStoreBrand($0.name) == desiredBrand } : stores

        for store in targetPool {
            let storeNorm = normalize(store.name)
            let storeCore = extractCoreKeyword(storeNorm)
            if storeNorm == normInput || (!storeCore.isEmpty && storeCore == coreInput) {
                return store
            }
        }

        for store in targetPool {
            for tok in store.keyTokens {
                let normTok = normalize(tok)
                if !normTok.isEmpty && (normTok == coreInput || normTok == normInput) {
                    return store
                }
            }
        }

        if coreInput.count >= 3 {
            let candidates = targetPool.filter { store in
                let storeCore = extractCoreKeyword(normalize(store.name))
                if storeCore.isEmpty { return false }
                if coreInput == storeCore { return true }
                if storeCore.contains(coreInput) { return true }
                if coreInput.contains(storeCore) {
                    return hasStoreKeyword || (coreInput.count <= storeCore.count + 5)
                }
                return false
            }
            if let best = candidates.max(by: { extractCoreKeyword(normalize($0.name)).count < extractCoreKeyword(normalize($1.name)).count }) {
                return best
            }
        }

        if normInput.count >= 8 {
            let matchAddr = targetPool.first { store in
                let addrNorm = normalize(store.address)
                return (coreInput.count >= 5 && addrNorm.contains(coreInput)) ||
                       (normInput.contains(addrNorm) || addrNorm.contains(normInput)) ||
                       (store.keyTokens.contains(where: { tok in
                           let nTok = normalize(tok)
                           return nTok.count >= 4 && normInput.contains(nTok)
                       }))
            }
            if let matchAddr = matchAddr { return matchAddr }
        }

        return nil
    }
}
