//
//  PlayerControlsView.swift
//  Created on 11/3/21.
//

import SwiftUI

public protocol PlayerControlsViewDisplayable: ObservableObject {
    var isPlaying: Bool { get }
    var images: [UIImage] { get }
    var tintColor: Color { get }
    
    func togglePlayPause()
    func next()
    func previous()
    func move(to imageIndex: Int)
}

struct PlayerControlsView<TimeLineViewModel>: View where TimeLineViewModel: PlayerControlsViewDisplayable {
    @ObservedObject var viewModel: TimeLineViewModel
    
    var body: some View {
        HStack(spacing: 25) {
            controls
            snapshots
                .frame(maxHeight: 66)
        }
    }
    
    var snapshots: some View {
        HStack {
            ForEach(viewModel.images, id: \.self) { image in
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .onTapGesture {
                        let index = viewModel.images.firstIndex(of: image) ?? 0
                        viewModel.move(to: index)
                    }
            }
        }
    }
    
    var controls: some View {
        HStack(spacing: 20) {
            previousButton
            playPauseButton
            nextButton
        }
        .font(.largeTitle)
        .tint(viewModel.tintColor)
    }
    
    var playPauseButton: some View {
        Button {
            viewModel.togglePlayPause()
        } label: {
            playPauseButtonLabel
        }
    }
    
    var playPauseButtonLabel: some View {
        Group {
            if viewModel.isPlaying {
                Image(systemName: "pause.fill")
            } else {
                Image(systemName: "play.fill")
            }
        }
    }
    
    var nextButton: some View {
        Button {
            viewModel.next()
        } label: {
            Image(systemName: "forward.end.fill")
        }
    }
    
    var previousButton: some View {
        Button {
            viewModel.previous()
        } label: {
            Image(systemName: "backward.end.fill")
        }
    }
}

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerControlsView(viewModel: Preview_MediaPlayerViewModel())
    }
}
