import SwiftUI

/// La striscia sopra la tab bar. Su iOS è volutamente povera: copertina,
/// titolo, play e avanti. Niente barra di avanzamento, niente sottotitolo.
struct MiniPlayerBar: View {
    @EnvironmentObject private var player: PlayerController

    let onTap: () -> Void

    var body: some View {
        if let track = player.current {
            HStack(spacing: 11) {
                ArtworkView(artKey: track.artKey)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                Text(track.title)
                    .font(.subheadline)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Button {
                    player.toggle()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                }
                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .frame(height: 56)
            // Il materiale di sistema: è il vetro vero di iOS, non una
            // sfocatura riprodotta a mano.
            .background(.regularMaterial)
            .overlay(alignment: .top) { Divider() }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
    }
}

struct NowPlayingView: View {
    @EnvironmentObject private var player: PlayerController
    @Environment(\.dismiss) private var dismiss

    @State private var scrubbing: Double?

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.tertiary)
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            Spacer()

            ArtworkView(artKey: player.current?.artKey, size: "full")
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.5), radius: 26, y: 14)
                .padding(.horizontal, 44)
                .scaleEffect(player.isPlaying ? 1 : 0.86)
                .animation(.spring(response: 0.45, dampingFraction: 0.8),
                           value: player.isPlaying)

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text(player.current?.title ?? "")
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                Text(player.current?.artistName ?? "")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)

            scrubber
                .padding(.horizontal, 32)
                .padding(.top, 18)

            controls
                .padding(.top, 10)

            Spacer()
        }
        .background {
            // Lo sfondo prende il colore della copertina e sfuma nel nero.
            ZStack {
                ArtworkView(artKey: player.current?.artKey, size: "full")
                    .scaleEffect(1.6)
                    .blur(radius: 90)
                    .opacity(0.55)
                LinearGradient(colors: [.clear, .black.opacity(0.85)],
                               startPoint: .top, endPoint: .bottom)
            }
            .ignoresSafeArea()
        }
        .presentationBackground(.black)
    }

    private var scrubber: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { scrubbing ?? player.position },
                    set: { scrubbing = $0 }
                ),
                in: 0...max(player.duration, 1),
                onEditingChanged: { editing in
                    if !editing, let value = scrubbing {
                        player.seek(to: value)
                        scrubbing = nil
                    }
                }
            )
            .tint(Theme.accent)

            HStack {
                Text((scrubbing ?? player.position).asClock)
                Spacer()
                Text(player.duration.asClock)
            }
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 34) {
            Button { player.previous() } label: {
                Image(systemName: "backward.fill").font(.title)
            }
            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 44))
            }
            Button { player.next() } label: {
                Image(systemName: "forward.fill").font(.title)
            }
        }
        .foregroundStyle(.primary)
    }
}
