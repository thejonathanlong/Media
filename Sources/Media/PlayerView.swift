//
//  PlayerView.swift
//  Created on 10/28/21.
//

import AVFoundation
import SwiftUI
import SwiftUIFoundation

public protocol PlayerViewDisplayable: PlayerControlsViewDisplayable, PlayerLayerViewDisplayable {
    
}

public struct PlayerView<ViewModel>: View where ViewModel: PlayerViewDisplayable {
    
    @ObservedObject var viewModel: ViewModel
    
    public init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            PlayerLayerView(viewModel: viewModel)
            PlayerControlsView(viewModel: viewModel)
                .padding()
                .background(.thinMaterial)
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
        Color.white
    }
    
    func togglePlayPause() {
        isPlaying.toggle()
    }
    
    func next() {
        
    }
    
    func previous() {
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
