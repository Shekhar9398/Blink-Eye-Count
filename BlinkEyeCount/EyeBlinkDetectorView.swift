import SwiftUI

struct EyeBlinkDetectorView: View {
    @StateObject private var viewModel = EyeBlinkDetectorViewModel()

    var body: some View {
        ZStack {
            CameraPreview(session: viewModel.captureSession)
                .onAppear {
                    viewModel.startSession()
                }
                .onDisappear {
                    viewModel.stopSession()
                }

            VStack {
                Spacer()
                Text("Blinks: \(viewModel.blinkCount)")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7).cornerRadius(10))
            }
            .padding()
        }
        .edgesIgnoringSafeArea(.all)
    }
}
