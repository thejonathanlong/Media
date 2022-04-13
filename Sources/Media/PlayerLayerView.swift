//
//  PlayerLayerView.swift
//  Created on 11/1/21.
//

import AVFoundation
import SwiftUI

public protocol PlayerLayerViewDisplayable: ObservableObject {
    var player: AVPlayer { get }
}

public struct PlayerLayerView<ViewModel>: View where ViewModel: PlayerLayerViewDisplayable {
    
    @ObservedObject var viewModel: ViewModel
    
    public var body: some View {
        PlayerLayerViewRepresentable(player: viewModel.player)
    }
}

public class PlayerLayerUIView: UIView {
    public override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }
    
    public var player: AVPlayer? {
        didSet {
            playerLayer.player = player
        }
    }
    
    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
    
    public init(player: AVPlayer? = nil) {
        self.player = player
        super.init(frame: .zero)
    }
    
    public override func layoutSubviews() {
        playerLayer.backgroundColor = UIColor.black.cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public struct PlayerLayerViewRepresentable : UIViewRepresentable {
    var player: AVPlayer?
    
    public func makeUIView(context: Context) -> PlayerLayerUIView {
        return PlayerLayerUIView(player: player)
    }
    
    public func updateUIView(_ uiView: PlayerLayerUIView, context: Context) {
        uiView.player = player
    }
}


class Preview_PlayerLayerViewModel: PlayerLayerViewDisplayable {
    var player: AVPlayer {
        return AVPlayer(url: URL(string: "https://movietrailers.apple.com/movies/disney/lightyear/lightyear-trailer-1_480p.mov")!)
    }
}

struct PlayerLayerView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerLayerView(viewModel: Preview_PlayerLayerViewModel())
            .background(Color.black)
.previewInterfaceOrientation(.landscapeLeft)
    }
}
