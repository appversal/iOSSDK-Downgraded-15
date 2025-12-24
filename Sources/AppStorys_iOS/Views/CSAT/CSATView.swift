//
//  CSATView.swift
//  AppStorys_iOS
//
//
//

import SwiftUI
import Kingfisher

struct CSATView: View {
    let sdk: AppStorys
    let campaignId: String
    let details: CsatDetails
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    @State private var selectedRating: Int?
    @State private var selectedFeedback: String?
    @State private var commentText: String = ""
    @State private var hasTrackedView = false
    @State private var isVisible = false
    @State private var showThankYou = false
    @FocusState private var isCommentFocused: Bool
    
    // MARK: - Computed UI
    
    private var backgroundColor: Color {
        Color(hex: details.styling?.csatBackgroundColor ?? "#FFFFFF")
    }
    
    private var titleColor: Color {
        Color(hex: details.styling?.csatTitleColor ?? "#000000")
    }
    
    private var descriptionColor: Color {
        Color(hex: details.styling?.csatDescriptionTextColor ?? "#666666")
    }
    
    private var fontSize: CGFloat {
        CGFloat(details.styling?.fontSize ?? 16)
    }
    
    private var displayDelay: TimeInterval {
        let ms = details.styling?.displayDelay ?? 0
        return TimeInterval(ms) / 1000.0
    }

    private var hasFeedbackOptions: Bool {
        !(details.feedbackOption?.options.isEmpty ?? true)
    }

    private var highStarColor: Color {
        Color(hex: details.styling?.csatHighStarColor ?? "#00B359")
    }
    
    private var lowStarColor: Color {
        Color(hex: details.styling?.csatLowStarColor ?? "#FF5757")
    }
    
    private var unselectedStarColor: Color {
        Color(hex: details.styling?.csatUnselectedStarColor ?? "#DDDDDD")
    }
    
    private var selectedOptionBackgroundColor: Color {
        Color(hex: details.styling?.csatSelectedOptionBackgroundColor ?? "#000000")
    }
    
    private var selectedOptionTextColor: Color {
        Color(hex: details.styling?.csatSelectedOptionTextColor ?? "#FFFFFF")
    }
    
    private var optionTextColor: Color {
        Color(hex: details.styling?.csatOptionTextColour ?? "#000000")
    }
    
    private var optionBoxColor: Color {
        Color(hex: details.styling?.csatOptionBoxColour ?? "#FFFFFF")
    }
    
    private var optionStrokeColor: Color {
        Color(hex: details.styling?.csatOptionStrokeColor ?? "#DFDFDF")
    }
    
    private var selectedOptionStrokeColor: Color {
        Color(hex: details.styling?.csatSelectedOptionStrokeColor ?? "#000000")
    }
    
    private var ctaBackgroundColor: Color {
        Color(hex: details.styling?.csatCtaBackgroundColor ?? "#000000")
    }
    
    private var ctaTextColor: Color {
        Color(hex: details.styling?.csatCtaTextColor ?? "#FFFFFF")
    }
    
    private var ctaButtonText: String {
        guard let rating = selectedRating else { return "Continue" }
        return rating >= 4 ? (details.highStarText ?? "Wonderful") : (details.lowStarText ?? "Help us improve")
    }
    
    private var additionalTextColor: Color {
        Color(hex: details.styling?.csatAdditionalTextColor ?? "#000000")
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            VStack {
                Spacer()
                
                containerGroup
                    .offset(y: isVisible ? 0 : 150)
                    .opacity(isVisible ? 1 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
            }
            .padding(.top)
        }
        .onAppear {
            handleAppear()
        }
    }
    
    // MARK: - Shared Container for CSAT + Thank You
    private var containerGroup: some View {
        ZStack {
            if showThankYou {
                thankYouInnerView
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .id("thankYou")
            } else {
                csatInnerView
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .id("csat")
            }
        }
        .frame(maxWidth: 500)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.thinMaterial, lineWidth: 1)
                )
        )
        .overlay(alignment: .topTrailing) {
            closeButton
                .padding(.top, 12)
                .padding(.trailing, 12)
        }
        .padding(.horizontal, 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: showThankYou)
    }

    
    // MARK: - Close Button Overlay
    
    private var closeButton: some View {
        Button(action: dismissWithTracking) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(.thinMaterial)
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - CSAT Content
    private var csatInnerView: some View {
        VStack(spacing: 16) {
            
            if let title = details.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: fontSize + 6, weight: .semibold))
                    .foregroundColor(titleColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            
            if let description = details.descriptionText {
                Text(description)
                    .font(.system(size: fontSize))
                    .foregroundColor(descriptionColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            
            starRatingView
            
            if selectedRating != nil && selectedRating! < 4 {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            expandedContentView
                            
                            // 👇 Anchor to scroll to when keyboard opens
                            Color.clear
                                .frame(height: 44)
                                .id("BOTTOM")
                        }
                    }
                    .onChangeCompat(of: isCommentFocused) { _, focused in
                        if focused {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeOut) {
                                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .scrollBounceCompat(.automatic) // ✅ This handles it automatically
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
            }
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }
    
    // MARK: Star Rating
    private var starRatingView: some View {
        HStack(spacing: 12) {
            ForEach(1...5, id: \.self) { index in
                let isSelected = isStarSelected(index)

                Button(action: { selectRating(index) }) {
                    Image(systemName: isSelected ? "star.fill" : "star")
                        .font(.system(size: 32))
                        .foregroundColor(getStarColor(for: index))
                        .scaleEffect(isSelected ? 1.18 : 1.0) // App Store-like pop
                        .animation(
                            .interpolatingSpring(
                                mass: 0.3,
                                stiffness: 200,
                                damping: 10,
                                initialVelocity: 0.3
                            )
                            .speed(1.2), // slightly snappier, exactly like App Store
                            value: selectedRating
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    
    private func isStarSelected(_ index: Int) -> Bool {
        (selectedRating ?? 0) >= index
    }
    
    private func getStarColor(for index: Int) -> Color {
        guard let rating = selectedRating else { return unselectedStarColor }
        return index <= rating ? (rating >= 4 ? highStarColor : lowStarColor) : unselectedStarColor
    }
    
    // MARK: Expanded Content (Feedback + Comment + Submit)
    
    private var expandedContentView: some View {
        VStack(spacing: 16) {
            
            let rating = selectedRating ?? 0
            let feedbackText = rating >= 4 ? (details.highStarText ?? "") : (details.lowStarText ?? "")
            
            if hasFeedbackOptions {
                feedbackOptionsView
            }
            
            // Comment box
            VStack(alignment: .leading, spacing: 8) {
                Text("Additional Comments")
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundColor(descriptionColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                MultilineTextInput(
                    placeholder: "Write your feedback...",
                    text: $commentText,
                    isFocused: $isCommentFocused
                )

                    .lineLimitCompat(3...5)
                    .padding(12)
                    .foregroundColor(additionalTextColor)
                    .focused($isCommentFocused)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(optionBoxColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(optionStrokeColor, lineWidth: 1.3)
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !ctaButtonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                submitButton
            }

        }
        .padding(.top, 4)
    }
    
    private var feedbackOptionsView: some View {
        VStack(spacing: 12) {
            if let options = details.feedbackOption?.options {
                ForEach(options, id: \.self) { option in
                    feedbackOptionButton(option)
                }
            }
        }
    }
    
    private func feedbackOptionButton(_ option: String) -> some View {
        let selected = selectedFeedback == option
        
        return Button(action: { selectFeedback(option) }) {
            HStack {
                Text(option)
                    .foregroundColor(selected ? selectedOptionTextColor : optionTextColor)
                    .font(.system(size: fontSize, weight: .medium))
                
                Spacer()
                
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(selected ? selectedOptionBackgroundColor : optionBoxColor)
            )
            .overlay(
                Capsule()
                    .stroke(selected ? selectedOptionStrokeColor : optionStrokeColor, lineWidth: 1.3)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: selected)
    }

    private var submitButton: some View {
        Button(action: submitFeedback) {
            Text("Submit")
                .font(.system(size: fontSize + 2, weight: .semibold))
                .foregroundColor(ctaTextColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(ctaBackgroundColor)
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Thank You View
    private var thankYouInnerView: some View {
        VStack(spacing: 24) {
            
            if let imageURL = details.thankyouImage,
               let sanitized = URLHelper.sanitizeURL(imageURL),
               let url = URL(string: sanitized) {
                KFImage(url)
                    .resizable()
//                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 200)
            }
            
            if let title = details.thankyouText {
                Text(title)
                    .font(.system(size: fontSize + 6, weight: .bold))
                    .foregroundColor(titleColor)
            }
            
            if let desc = details.thankyouDescription {
                Text(desc)
                    .font(.system(size: fontSize))
                    .foregroundColor(descriptionColor)
                    .multilineTextAlignment(.center)
            }
            
            if let link = details.link,
               !ctaButtonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

                Button(action: { handleCTAClick(link) }) {
                    Text(ctaButtonText)
                        .font(.system(size: fontSize + 2, weight: .semibold))
                        .foregroundColor(ctaTextColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            Capsule()
                                .fill(ctaBackgroundColor)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }
    
    // MARK: - Actions
    
    private func selectRating(_ rating: Int) {
        selectedRating = rating
        
        Task {
            await sdk.trackEvents(
                eventType: "star_selected",
                campaignId: campaignId,
                metadata: ["rating": rating]
            )
        }
        
        // Auto-submit for high ratings (4-5 stars)
        if rating >= 4 {
                submitFeedback()
        }
    }
    
    private func selectFeedback(_ option: String) {
        selectedFeedback = option
        
        Task {
            await sdk.trackEvents(
                eventType: "feedback_selected",
                campaignId: campaignId,
                metadata: ["feedback": option]
            )
        }
    }

    private func submitFeedback() {
        guard let rating = selectedRating else {
            Logger.warning("⚠️ Cannot submit without rating")
            return
        }
        
        // ✅ Build metadata for analytics tracking
        var metadata: [String: Any] = ["rating": rating]
        if let feedback = selectedFeedback { metadata["feedback"] = feedback }
        if !commentText.isEmpty { metadata["comment"] = commentText }
        
        Task {
            // ✅ Track submission event (for analytics)
            await sdk.trackEvents(
                eventType: "submitted",
                campaignId: campaignId,
                metadata: metadata
            )
            
            // ✅ NEW: Capture structured CSAT response (separate endpoint)
            do {
                try await sdk.captureCsatResponse(
                    csatId: details.id,  // Use CSAT detail ID, not campaign ID
                    rating: rating,
                    feedbackOption: selectedFeedback,
                    additionalComments: commentText.isEmpty ? nil : commentText
                )
                
                Logger.info("✅ CSAT response submitted successfully")
                
            } catch {
                Logger.error("❌ Failed to submit CSAT response", error: error)
                // Don't block UI - response is queued for retry
            }
        }
        
        // Show thank you screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(.spring) {
                showThankYou = true
            }
        }
    }
    
    private func handleCTAClick(_ link: String) {
        Task {
            await sdk.trackEvents(
                eventType: "cta_clicked",
                campaignId: campaignId,
                metadata: [
                    "link": link,
                    "rating": selectedRating ?? 0,
                    "cta_text": ctaButtonText
                ]
            )
        }
        
        if let url = URL(string: URLHelper.sanitizeURL(link) ?? "") {
            UIApplication.shared.open(url)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            dismissWithTracking()
        }
    }
    
    private func dismissWithTracking() {
        Task {
            await sdk.trackEvents(
                eventType: "dismissed",
                campaignId: campaignId,
                metadata: [
                    "rating": selectedRating ?? 0,
                    "completed": showThankYou
                ]
            )
        }
        
        sdk.dismissCampaign(campaignId)
        
        isVisible = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
    
    private func handleAppear() {
        if !hasTrackedView {
            hasTrackedView = true
            
            Task {
                await sdk.trackEvents(
                    eventType: "viewed",
                    campaignId: campaignId,
                    metadata: ["screen": sdk.currentScreen ?? "unknown"]
                )
            }
        }
        
        Task {
            try? await Task.sleep(nanoseconds: UInt64(displayDelay * 1_000_000_000))
            isVisible = true
        }
    }
}


// MARK: - Preview

#if DEBUG
#Preview("CSAT Survey") {
    ZStack {
        Color.clear
        CSATView(
            sdk: .shared,
            campaignId: "preview-csat",
            details: createMockCSAT()
        )
    }
}

private func createMockCSAT() -> CsatDetails {
    let styling: [String: Any] = [
        "displayDelay": "0",
        "fontSize": 16,
        "csatTitleColor": "#000000",
        "csatBackgroundColor": "#ffffff",
        "csatDescriptionTextColor": "#666666",
        "csatCtaBackgroundColor": "#000000",
        "csatCtaTextColor": "#ffffff"
    ]
    
    let starColors: [String: Any] = [
        "csatHighStarColor": "#00b359",
        "csatLowStarColor": "#ff5757",
        "csatUnselectedStarColor": "#dfdfdf"
    ]
    
    let optionColors: [String: Any] = [
        "csatOptionTextColour": "#000000",
        "csatOptionBoxColour": "#ffffff",
        "csatOptionStrokeColor": "#dfdfdf",
        "csatSelectedOptionTextColor": "#ffffff",
        "csatSelectedOptionBackgroundColor": "#000000",
        "csatSelectedOptionStrokeColor": "#000000"
    ]
    
    let feedbackOptions: [String: Any] = [
        "option1": "Excellent",
        "option2": "Good"
    ]
    
    var combinedStyling = styling
    combinedStyling.merge(starColors) { _, new in new }
    combinedStyling.merge(optionColors) { _, new in new }
    
    let mockData: [String: Any] = [
        "id": "preview-1",
        "title": "How would you rate your experience?",
        "description_text": "Rate between 1 to 5",
        "highStarText": "Wonderful",
        "lowStarText": "Help us improve",
        "thankyouText": "Thank you!",
        "thankyouDescription": "We appreciate your feedback",
        "thankyouImage": "https://cdn.appstorys.com/thankyouImage/favicon.6bbdf3a8.png",
        "link": "https://www.google.com",
        "styling": combinedStyling,
        "feedback_option": feedbackOptions
    ]
    
    let jsonData = try! JSONSerialization.data(withJSONObject: mockData)
    return try! JSONDecoder().decode(CsatDetails.self, from: jsonData)
}
#endif
