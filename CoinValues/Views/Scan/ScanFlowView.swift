import PhotosUI
import SwiftData
import SwiftUI

/// Front photo → back photo → identification → result, presented full screen.
struct ScanFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionStore.self) private var store

    enum Step: Equatable {
        case front, back, analyzing
        case failed(String, needsSubscription: Bool)
        case done(UUID)
    }

    @State private var step: Step = .front
    @State private var camera = CameraController()
    @State private var frontImage: UIImage?
    @State private var backImage: UIImage?
    @State private var result: CoinScan?
    @State private var pickerItem: PhotosPickerItem?
    @State private var isCapturing = false
    @State private var showPaywall = false
    @State private var screenSize: CGSize = .zero

    var body: some View {
        Group {
            switch step {
            case .front, .back:
                captureView
            case .analyzing:
                AnalyzingView(image: frontImage)
            case .failed(let message, let needsSubscription):
                failureView(message: message, needsSubscription: needsSubscription)
            case .done:
                if let result {
                    NavigationStack {
                        CoinDetailView(coin: result, isNewResult: true)
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button("Done") { dismiss() }
                                }
                            }
                    }
                }
            }
        }
        .task {
            #if DEBUG
            if DemoMode.screen == "analyzing" {
                frontImage = DemoMode.image(named: "analyzing.jpg")
                step = .analyzing
            }
            if DemoMode.isEnabled { return }
            #endif
            await camera.start()
        }
        .onDisappear { camera.stop() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await usePickedPhoto(item) }
        }
        .fullScreenCover(isPresented: $showPaywall) { PaywallView() }
    }

    // MARK: - Capture

    /// Laid out over the full screen, because the preview and the guide circle are both centred on it
    /// and the photo crop is computed from that geometry.
    private var captureView: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let guide = guideDiameter(for: size)
            ZStack {
                Color.black
                if camera.status == .ready {
                    CameraPreview(session: camera.session)
                } else if let demo = demoPreview {
                    Image(uiImage: demo).resizable().scaledToFill().frame(width: size.width, height: size.height).clipped()
                } else {
                    cameraUnavailable
                        .position(x: size.width / 2, y: size.height / 2)
                }
                GuideOverlay(diameter: guide)
                    .allowsHitTesting(false)
                    .opacity(showsViewfinder ? 1 : 0)

                VStack(spacing: 6) {
                    Text(step == .front ? "Fit the front of the coin in the circle" : "Now flip it and fit the back in the circle")
                        .font(.headline)
                    Text("Get close in good light so the date and mint mark are sharp.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .frame(width: size.width)
                .position(x: size.width / 2, y: size.height / 2 + guide / 2 + 52)
                .opacity(showsViewfinder ? 1 : 0)

            }
            .onAppear { screenSize = size }
            .onChange(of: size) { _, newSize in screenSize = newSize }
        }
        .ignoresSafeArea()
        // The controls sit in an overlay so they keep to the safe area.
        .overlay {
            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomBar(previewSize: screenSize, guide: guideDiameter(for: screenSize))
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }

    private func guideDiameter(for size: CGSize) -> CGFloat { min(size.width * 0.78, 340) }

    private var showsViewfinder: Bool { camera.status == .ready || demoPreview != nil }

    private var demoPreview: UIImage? {
        #if DEBUG
        if DemoMode.screen == "scan" { return DemoMode.image(named: "viewfinder.jpg") }
        #endif
        return nil
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.45), in: Circle())
            }
            .accessibilityLabel("Close")
            Spacer()
            VStack(spacing: 2) {
                Text(step == .front ? "Front Side" : "Back Side").font(.headline)
                Text(step == .front ? "Step 1 of 2" : "Step 2 of 2").font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            if let frontImage, step == .back {
                Image(uiImage: frontImage)
                    .resizable().scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Theme.gold, lineWidth: 2))
                    .accessibilityLabel("Front photo taken")
            } else {
                Color.clear.frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func bottomBar(previewSize: CGSize, guide: CGFloat) -> some View {
        VStack(spacing: 16) {
            if step == .back {
                Button("Skip back side") { startIdentification() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.goldLight)
            }
            HStack {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 52, height: 52)
                        .background(.white.opacity(0.15), in: Circle())
                }
                .accessibilityLabel("Choose from Photos")
                Spacer()
                Button {
                    Task { await capture(previewSize: previewSize, guide: guide) }
                } label: {
                    ZStack {
                        Circle().strokeBorder(.white, lineWidth: 4).frame(width: 78, height: 78)
                        Circle().fill(Theme.goldGradient).frame(width: 64, height: 64)
                    }
                }
                .disabled(camera.status != .ready || isCapturing)
                .opacity(showsViewfinder ? 1 : 0.4)
                .accessibilityLabel("Take photo")
                Spacer()
                Button {
                    camera.setTorch(!camera.isTorchOn)
                } label: {
                    Image(systemName: camera.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 52, height: 52)
                        .background(.white.opacity(camera.isTorchOn ? 0.35 : 0.15), in: Circle())
                }
                .disabled(!camera.hasTorch)
                .opacity(camera.hasTorch ? 1 : 0.4)
                .accessibilityLabel(camera.isTorchOn ? "Turn light off" : "Turn light on")
            }
            .padding(.horizontal, 36)
        }
        .padding(.bottom, 24)
    }

    private var cameraUnavailable: some View {
        VStack(spacing: 14) {
            Image(systemName: camera.status == .denied ? "camera.badge.ellipsis" : "camera")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.6))
            Text(camera.status == .denied ? "Camera access is off" : "Camera unavailable")
                .font(.headline)
            Text(camera.status == .denied
                 ? "Allow camera access in Settings to photograph coins, or choose photos from your library."
                 : "You can still choose coin photos from your library.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            if camera.status == .denied, let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url)
                    .font(.headline)
                    .foregroundStyle(Theme.goldLight)
            }
        }
        .foregroundStyle(.white)
        .padding(32)
        .opacity(camera.status == .unknown ? 0 : 1)
    }

    private func capture(previewSize: CGSize, guide: CGFloat) async {
        isCapturing = true
        defer { isCapturing = false }
        guard let photo = await camera.capture() else { return }
        accept(ImageProcessing.prepareCameraPhoto(photo, previewSize: previewSize, guideDiameter: guide))
    }

    private func usePickedPhoto(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
        accept(ImageProcessing.prepareLibraryPhoto(image))
    }

    private func accept(_ image: UIImage) {
        if step == .front {
            frontImage = image
            withAnimation { step = .back }
        } else {
            backImage = image
            startIdentification()
        }
    }

    // MARK: - Identification

    private func startIdentification() {
        guard let frontImage, let frontData = ImageProcessing.jpeg(frontImage) else { return }
        let backData = backImage.flatMap(ImageProcessing.jpeg)
        camera.stop()
        withAnimation { step = .analyzing }
        Task {
            do {
                let identifier = CoinIdentifier(transactionJWS: store.activeTransactionJWS)
                let identification = try await identifier.identify(front: frontData, back: backData)
                let scan = CoinScan(identification: identification, frontImage: frontData, backImage: backData)
                modelContext.insert(scan)
                try? modelContext.save()
                result = scan
                withAnimation { step = .done(scan.id) }
            } catch let error as CoinIdentifier.IdentifyError {
                if case .subscriptionRequired = error { await store.refreshEntitlements() }
                step = .failed(error.localizedDescription, needsSubscription: error == .subscriptionRequired)
            } catch {
                step = .failed(CoinIdentifier.IdentifyError.server.localizedDescription, needsSubscription: false)
            }
        }
    }

    private func failureView(message: String, needsSubscription: Bool) -> some View {
        VStack(spacing: 18) {
            Spacer()
            CoinGlyph(symbol: "questionmark", size: 110)
            Text(needsSubscription ? "Subscription needed" : "Couldn't identify this coin")
                .font(.title2.weight(.bold))
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            VStack(spacing: 12) {
                if needsSubscription {
                    Button("See Plans") { showPaywall = true }.buttonStyle(.primary)
                } else {
                    Button("Try Again") { retake() }.buttonStyle(.primary)
                }
                Button("Close") { dismiss() }
                    .font(.headline)
                    .padding(.vertical, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private func retake() {
        frontImage = nil
        backImage = nil
        step = .front
        Task { await camera.start() }
    }
}

/// Darkens everything outside the guide circle.
private struct GuideOverlay: View {
    let diameter: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            ZStack {
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: proxy.size))
                    path.addEllipse(in: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter))
                }
                .fill(.black.opacity(0.55), style: FillStyle(eoFill: true))
                Circle()
                    .strokeBorder(Theme.goldGradient, lineWidth: 3)
                    .frame(width: diameter, height: diameter)
                    .position(center)
            }
        }
    }
}

extension CoinIdentifier.IdentifyError: Equatable {}
