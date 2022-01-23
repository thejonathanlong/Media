//
//  PlayerView.swift
//  Created on 10/28/21.
//

import AVFoundation
import SwiftUI
import SwiftUIFoundation

public protocol PlayerViewDisplayable: PlayerControlsViewDisplayable, PlayerLayerViewDisplayable {
    func dismiss()
}

public struct PlayerView<ViewModel>: View where ViewModel: PlayerViewDisplayable {
    
    @ObservedObject var viewModel: ViewModel
    
    var wantsCloseButton: Bool
    
    public init(viewModel: ViewModel,
                wantsCloseButton: Bool = true) {
        self.viewModel = viewModel
        self.wantsCloseButton = wantsCloseButton
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            ZStack(alignment: .topLeading) {
                PlayerLayerView(viewModel: viewModel)
                Button {
                    viewModel.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.largeTitle)
                        .foregroundColor(viewModel.tintColor)
                        .padding()
                }
                
                .background(VisualEffectViewRepresentable(effect: UIBlurEffect(style: .systemThinMaterialDark)))
                .cornerRadius(12, corners: .allCorners, backgroundColor: .clear)
                .offset(x: 16, y: 16)
                
                
            }
            PlayerControlsView(viewModel: viewModel)
                .padding()
                .background(VisualEffectViewRepresentable(effect: UIBlurEffect(style: .systemThinMaterialDark)))
                .cornerRadius(12, corners: .allCorners, backgroundColor: .clear)
            
        }
    }
}

class Preview_MediaPlayerViewModel: PlayerViewDisplayable {
    var player: AVPlayer? {
        return AVPlayer(url: URL(string: "https://movietrailers.apple.com/movies/disney/lightyear/lightyear-trailer-1_480p.mov")!)
    }
    
    var images: [UIImage] = [UIImage(systemName: "flame.fill")!,
                             UIImage(systemName: "drop.fill")!,
                             UIImage(systemName: "bolt.fill")!,
                             UIImage(systemName: "flame.fill")!,
                             UIImage(systemName: "drop.fill")!,
                             UIImage(systemName: "bolt.fill")!]
    
    @Published var isPlaying: Bool = false
    
    var tintColor: Color {
        Color.red
    }
    
    func togglePlayPause() {
        isPlaying.toggle()
    }
    
    func next() {
        
    }
    
    func previous() {
    }
    
    func dismiss() {
        
    }
    
    func move(to imageIndex: Int) {
        
    }
}

struct MediaPlayer_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            PlayerView(viewModel: Preview_MediaPlayerViewModel())
//                .padding()
                .background(Color.red)
        }
.previewInterfaceOrientation(.landscapeLeft)
.colorScheme(.dark)
    }
}
