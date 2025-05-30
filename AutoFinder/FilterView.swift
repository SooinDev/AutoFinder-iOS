import SwiftUI
import Combine

// MARK: - 고급 필터 뷰
struct FilterView: View {
    @Binding var filters: CarFilterParams
    let onApply: (CarFilterParams) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    @State private var tempFilters: CarFilterParams
    @State private var priceRange: ClosedRange<Double> = 0...10000
    @State private var yearRange: ClosedRange<Double> = 1990...2024
    @State private var mileageRange: ClosedRange<Double> = 0...300000
    @State private var selectedBrands: Set<String> = []
    @State private var selectedFuelTypes: Set<String> = []
    @State private var selectedRegions: Set<String> = []
    
    init(filters: Binding<CarFilterParams>, onApply: @escaping (CarFilterParams) -> Void) {
        self._filters = filters
        self.onApply = onApply
        self._tempFilters = State(initialValue: filters.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: UIConstants.Spacing.lg) {
                    // 가격 필터
                    PriceFilterSection(
                        range: $priceRange,
                        filters: $tempFilters
                    )
                    
                    // 연식 필터
                    YearFilterSection(
                        range: $yearRange,
                        filters: $tempFilters
                    )
                    
                    // 주행거리 필터
                    MileageFilterSection(
                        range: $mileageRange,
                        filters: $tempFilters
                    )
                    
                    // 브랜드 필터
                    BrandFilterSection(
                        selectedBrands: $selectedBrands,
                        filters: $tempFilters
                    )
                    
                    // 연료 타입 필터
                    FuelTypeFilterSection(
                        selectedFuelTypes: $selectedFuelTypes,
                        filters: $tempFilters
                    )
                    
                    // 지역 필터
                    RegionFilterSection(
                        selectedRegions: $selectedRegions,
                        filters: $tempFilters
                    )
                }
                .padding()
            }
            .navigationTitle("상세 필터")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("초기화") {
                        resetFilters()
                    }
                    .foregroundColor(Color(UIConstants.Colors.accentColor))
                }
            }
            .safeAreaInset(edge: .bottom) {
                FilterBottomActionView(
                    onApply: applyFilters,
                    onReset: resetFilters
                )
                .padding()
                .background(Color(UIConstants.Colors.cardBackground))
            }
        }
        .onAppear {
            initializeFilters()
        }
    }
    
    private func initializeFilters() {
        tempFilters = filters
        
        // 가격 범위 설정
        priceRange = Double(tempFilters.minPrice ?? 0)...Double(tempFilters.maxPrice ?? 10000)
        
        // 연식 범위 설정
        yearRange = Double(tempFilters.minYear ?? 1990)...Double(tempFilters.maxYear ?? 2024)
        
        // 주행거리 범위 설정
        mileageRange = Double(tempFilters.minMileage ?? 0)...Double(tempFilters.maxMileage ?? 300000)
        
        // 선택된 옵션들 설정
        if let model = tempFilters.model {
            selectedBrands.insert(model)
        }
        if let fuel = tempFilters.fuel {
            selectedFuelTypes.insert(fuel)
        }
        if let region = tempFilters.region {
            selectedRegions.insert(region)
        }
    }
    
    @discardableResult
    private func applyFilters() {
        // 범위 값들을 필터에 적용
        tempFilters.minPrice = Int(priceRange.lowerBound)
        tempFilters.maxPrice = Int(priceRange.upperBound)
        tempFilters.minYear = Int(yearRange.lowerBound)
        tempFilters.maxYear = Int(yearRange.upperBound)
        tempFilters.minMileage = Int(mileageRange.lowerBound)
        tempFilters.maxMileage = Int(mileageRange.upperBound)
        
        // 선택된 옵션들 적용
        tempFilters.model = selectedBrands.first
        tempFilters.fuel = selectedFuelTypes.first
        tempFilters.region = selectedRegions.first
        
        onApply(tempFilters)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func resetFilters() {
        tempFilters = CarFilterParams()
        priceRange = 0...10000
        yearRange = 1990...2024
        mileageRange = 0...300000
        selectedBrands.removeAll()
        selectedFuelTypes.removeAll()
        selectedRegions.removeAll()
    }
}

// MARK: - 가격 필터 섹션
struct PriceFilterSection: View {
    @Binding var range: ClosedRange<Double>
    @Binding var filters: CarFilterParams
    
    var body: some View {
        FilterSectionView(title: "가격", icon: "wonsign.circle.fill") {
            VStack(spacing: UIConstants.Spacing.md) {
                HStack {
                    Text("\(Int(range.lowerBound))만원")
                        .font(.subheadline)
                        .foregroundColor(Color(UIConstants.Colors.textSecondary))
                    
                    Spacer()
                    
                    Text("\(Int(range.upperBound))만원")
                        .font(.subheadline)
                        .foregroundColor(Color(UIConstants.Colors.textSecondary))
                }
                
                RangeSlider(range: $range, bounds: 0...10000, step: 100)
                
                // 가격 범위 프리셋
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: UIConstants.Spacing.sm) {
                    ForEach(CarConstants.priceRanges.sorted(by: { $0.value.min < $1.value.min }), id: \.key) { key, value in
                        Button(action: {
                            let maxValue = value.max == Int.max ? 10000 : value.max
                            range = Double(value.min)...Double(maxValue)
                        }) {
                            Text(key)
                                .font(.caption)
                                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                                .padding(.horizontal, UIConstants.Spacing.sm)
                                .padding(.vertical, UIConstants.Spacing.xs)
                                .background(Color(UIConstants.Colors.primaryBlue).opacity(0.1))
                                .cornerRadius(UIConstants.CornerRadius.small)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 연식 필터 섹션
struct YearFilterSection: View {
    @Binding var range: ClosedRange<Double>
    @Binding var filters: CarFilterParams
    
    var body: some View {
        FilterSectionView(title: "연식", icon: "calendar.circle.fill") {
            VStack(spacing: UIConstants.Spacing.md) {
                HStack {
                    Text("\(Int(range.lowerBound))년")
                        .font(.subheadline)
                        .foregroundColor(Color(UIConstants.Colors.textSecondary))
                    
                    Spacer()
                    
                    Text("\(Int(range.upperBound))년")
                        .font(.subheadline)
                        .foregroundColor(Color(UIConstants.Colors.textSecondary))
                }
                
                RangeSlider(range: $range, bounds: 1990...2024, step: 1)
                
                // 연식 프리셋
                HStack(spacing: UIConstants.Spacing.sm) {
                    ForEach(["2020년 이후", "2015년 이후", "2010년 이후"], id: \.self) { preset in
                        Button(action: {
                            switch preset {
                            case "2020년 이후":
                                range = 2020...2024
                            case "2015년 이후":
                                range = 2015...2024
                            case "2010년 이후":
                                range = 2010...2024
                            default:
                                break
                            }
                        }) {
                            Text(preset)
                                .font(.caption)
                                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                                .padding(.horizontal, UIConstants.Spacing.sm)
                                .padding(.vertical, UIConstants.Spacing.xs)
                                .background(Color(UIConstants.Colors.primaryBlue).opacity(0.1))
                                .cornerRadius(UIConstants.CornerRadius.small)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 주행거리 필터 섹션
struct MileageFilterSection: View {
    @Binding var range: ClosedRange<Double>
    @Binding var filters: CarFilterParams
    
    var body: some View {
        FilterSectionView(title: "주행거리", icon: "speedometer.circle.fill") {
            VStack(spacing: UIConstants.Spacing.md) {
                HStack {
                    Text("\(formatMileage(Int(range.lowerBound)))")
                        .font(.subheadline)
                        .foregroundColor(Color(UIConstants.Colors.textSecondary))
                    
                    Spacer()
                    
                    Text("\(formatMileage(Int(range.upperBound)))")
                        .font(.subheadline)
                        .foregroundColor(Color(UIConstants.Colors.textSecondary))
                }
                
                RangeSlider(range: $range, bounds: 0...300000, step: 5000)
                
                // 주행거리 프리셋
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: UIConstants.Spacing.sm) {
                    ForEach(CarConstants.mileageRanges.sorted(by: { $0.value.min < $1.value.min }), id: \.key) { key, value in
                        Button(action: {
                            let maxValue = value.max == Int.max ? 300000 : value.max
                            range = Double(value.min)...Double(maxValue)
                        }) {
                            Text(key)
                                .font(.caption)
                                .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                                .padding(.horizontal, UIConstants.Spacing.sm)
                                .padding(.vertical, UIConstants.Spacing.xs)
                                .background(Color(UIConstants.Colors.primaryBlue).opacity(0.1))
                                .cornerRadius(UIConstants.CornerRadius.small)
                        }
                    }
                }
            }
        }
    }
    
    private func formatMileage(_ mileage: Int) -> String {
        if mileage >= 10000 {
            return "\(mileage / 10000)만km"
        } else {
            return "\(mileage)km"
        }
    }
}

// MARK: - 브랜드 필터 섹션
struct BrandFilterSection: View {
    @Binding var selectedBrands: Set<String>
    @Binding var filters: CarFilterParams
    
    private let brands = ["현대", "기아", "제네시스", "BMW", "벤츠", "아우디", "르노", "쉐보레", "쌍용", "볼보"]
    
    var body: some View {
        FilterSectionView(title: "브랜드", icon: "car.circle.fill") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: UIConstants.Spacing.sm) {
                ForEach(brands, id: \.self) { brand in
                    FilterToggleButton(
                        title: brand,
                        isSelected: selectedBrands.contains(brand),
                        onToggle: {
                            if selectedBrands.contains(brand) {
                                selectedBrands.remove(brand)
                            } else {
                                selectedBrands.removeAll() // 단일 선택
                                selectedBrands.insert(brand)
                            }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - 연료 타입 필터 섹션
struct FuelTypeFilterSection: View {
    @Binding var selectedFuelTypes: Set<String>
    @Binding var filters: CarFilterParams
    
    var body: some View {
        FilterSectionView(title: "연료", icon: "fuelpump.circle.fill") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: UIConstants.Spacing.sm) {
                ForEach(CarConstants.fuelTypes, id: \.self) { fuel in
                    FilterToggleButton(
                        title: fuel,
                        isSelected: selectedFuelTypes.contains(fuel),
                        onToggle: {
                            if selectedFuelTypes.contains(fuel) {
                                selectedFuelTypes.remove(fuel)
                            } else {
                                selectedFuelTypes.removeAll() // 단일 선택
                                selectedFuelTypes.insert(fuel)
                            }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - 지역 필터 섹션
struct RegionFilterSection: View {
    @Binding var selectedRegions: Set<String>
    @Binding var filters: CarFilterParams
    
    var body: some View {
        FilterSectionView(title: "지역", icon: "location.circle.fill") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: UIConstants.Spacing.sm) {
                ForEach(CarConstants.regions, id: \.self) { region in
                    FilterToggleButton(
                        title: region,
                        isSelected: selectedRegions.contains(region),
                        onToggle: {
                            if selectedRegions.contains(region) {
                                selectedRegions.remove(region)
                            } else {
                                selectedRegions.removeAll() // 단일 선택
                                selectedRegions.insert(region)
                            }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - 필터 섹션 뷰
struct FilterSectionView<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Color(UIConstants.Colors.primaryBlue))
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(UIConstants.Colors.textPrimary))
                
                Spacer()
            }
            
            content
        }
        .padding()
        .background(Color(UIConstants.Colors.cardBackground))
        .cornerRadius(UIConstants.CornerRadius.medium)
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 4,
            x: 0,
            y: 2
        )
    }
}

// MARK: - 필터 토글 버튼
struct FilterToggleButton: View {
    let title: String
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : Color(UIConstants.Colors.primaryBlue))
                .padding(.horizontal, UIConstants.Spacing.sm)
                .padding(.vertical, UIConstants.Spacing.xs)
                .background(isSelected ? Color(UIConstants.Colors.primaryBlue) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: UIConstants.CornerRadius.small)
                        .stroke(Color(UIConstants.Colors.primaryBlue), lineWidth: 1)
                )
                .cornerRadius(UIConstants.CornerRadius.small)
        }
    }
}

// MARK: - 범위 슬라이더
struct RangeSlider: View {
    @Binding var range: ClosedRange<Double>
    let bounds: ClosedRange<Double>
    let step: Double
    
    var body: some View {
        VStack {
            // 사용자 정의 범위 슬라이더 구현 (SwiftUI 기본 제공되지 않음)
            // 여기서는 간단한 버전으로 구현
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 배경 트랙
                    Rectangle()
                        .fill(Color(UIConstants.Colors.backgroundColor))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    // 선택된 범위
                    Rectangle()
                        .fill(Color(UIConstants.Colors.primaryBlue))
                        .frame(
                            width: CGFloat((range.upperBound - range.lowerBound) / (bounds.upperBound - bounds.lowerBound)) * geometry.size.width,
                            height: 4
                        )
                        .offset(x: CGFloat((range.lowerBound - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)) * geometry.size.width)
                        .cornerRadius(2)
                }
            }
            .frame(height: 20)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let percent = Double(value.location.x / UIScreen.main.bounds.width)
                        let newValue = bounds.lowerBound + (bounds.upperBound - bounds.lowerBound) * percent
                        let clampedValue = max(bounds.lowerBound, min(bounds.upperBound, newValue))
                        
                        // 간단한 범위 업데이트 로직
                        if abs(clampedValue - range.lowerBound) < abs(clampedValue - range.upperBound) {
                            range = clampedValue...range.upperBound
                        } else {
                            range = range.lowerBound...clampedValue
                        }
                    }
            )
        }
    }
}

// MARK: - 하단 액션 뷰
struct FilterBottomActionView: View {
    let onApply: () -> Void
    let onReset: () -> Void
    
    var body: some View {
        HStack(spacing: UIConstants.Spacing.md) {
            Button("초기화") {
                onReset()
            }
            .buttonStyle(AppSecondaryButtonStyle()) // SecondaryButtonStyle() → AppSecondaryButtonStyle()
            
            Button("적용") {
                onApply()
            }
            .buttonStyle(AppPrimaryButtonStyle()) // PrimaryButtonStyle() → AppPrimaryButtonStyle()
        }
    }
}

// MARK: - 확장: CarFilterParams
extension CarFilterParams {
    var minYear: Int? {
        get { nil } // 기존 CarFilterParams에는 없으므로 확장 필요
        set { }
    }
    
    var maxYear: Int? {
        get { nil }
        set { }
    }
}

// MARK: - 프리뷰
struct FilterView_Previews: PreviewProvider {
    static var previews: some View {
        FilterView(
            filters: .constant(CarFilterParams()),
            onApply: { _ in }
        )
        .preferredColorScheme(.light)
        .previewDisplayName("Filter View - Light")
    }
}
