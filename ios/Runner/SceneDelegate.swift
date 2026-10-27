import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// Scene-based privacy cover for the iOS app switcher snapshot.
  private var privacyCover: UIView?

  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    coverWindow()
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    revealWindow()
  }

  private func coverWindow() {
    guard privacyCover == nil, let window else { return }
    let cover = UIView(frame: window.bounds)
    cover.backgroundColor = UIColor(
      red: 245 / 255, green: 241 / 255, blue: 232 / 255, alpha: 1
    )
    cover.frame = window.bounds
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    let card = UIView()
    card.translatesAutoresizingMaskIntoConstraints = false
    card.backgroundColor = .white
    card.layer.cornerRadius = 28
    card.layer.cornerCurve = .continuous
    card.layer.shadowColor = UIColor.black.withAlphaComponent(0.08).cgColor
    card.layer.shadowOpacity = 1
    card.layer.shadowRadius = 20
    card.layer.shadowOffset = CGSize(width: 0, height: 8)

    let iconWrap = UIView()
    iconWrap.translatesAutoresizingMaskIntoConstraints = false
    iconWrap.backgroundColor = UIColor(
      red: 91 / 255, green: 124 / 255, blue: 106 / 255, alpha: 1
    )
    iconWrap.layer.cornerRadius = 32
    iconWrap.layer.cornerCurve = .continuous

    let icon = UIImageView(image: UIImage(systemName: "lock.fill"))
    icon.translatesAutoresizingMaskIntoConstraints = false
    icon.tintColor = .white
    icon.contentMode = .scaleAspectFit

    let titleLabel = UILabel()
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.text = "UnderCroft"
    titleLabel.textAlignment = .center
    titleLabel.font = .systemFont(ofSize: 28, weight: .semibold)
    titleLabel.textColor = UIColor(
      red: 47 / 255, green: 51 / 255, blue: 48 / 255, alpha: 1
    )

    let subtitleLabel = UILabel()
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
    subtitleLabel.text = "Protected while the app is in the background"
    subtitleLabel.textAlignment = .center
    subtitleLabel.numberOfLines = 0
    subtitleLabel.font = .systemFont(ofSize: 15, weight: .medium)
    subtitleLabel.textColor = UIColor(
      red: 96 / 255, green: 104 / 255, blue: 98 / 255, alpha: 1
    )

    let hintLabel = UILabel()
    hintLabel.translatesAutoresizingMaskIntoConstraints = false
    hintLabel.text = "Unlock with Face ID to continue"
    hintLabel.textAlignment = .center
    hintLabel.font = .systemFont(ofSize: 14, weight: .regular)
    hintLabel.textColor = UIColor(
      red: 122 / 255, green: 129 / 255, blue: 124 / 255, alpha: 1
    )

    cover.addSubview(card)
    card.addSubview(iconWrap)
    iconWrap.addSubview(icon)
    card.addSubview(titleLabel)
    card.addSubview(subtitleLabel)
    card.addSubview(hintLabel)

    NSLayoutConstraint.activate([
      card.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
      card.centerYAnchor.constraint(equalTo: cover.centerYAnchor),
      card.leadingAnchor.constraint(greaterThanOrEqualTo: cover.leadingAnchor, constant: 28),
      card.trailingAnchor.constraint(lessThanOrEqualTo: cover.trailingAnchor, constant: -28),
      card.widthAnchor.constraint(equalToConstant: 300),

      iconWrap.topAnchor.constraint(equalTo: card.topAnchor, constant: 28),
      iconWrap.centerXAnchor.constraint(equalTo: card.centerXAnchor),
      iconWrap.widthAnchor.constraint(equalToConstant: 64),
      iconWrap.heightAnchor.constraint(equalToConstant: 64),

      icon.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
      icon.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),
      icon.widthAnchor.constraint(equalToConstant: 28),
      icon.heightAnchor.constraint(equalToConstant: 28),

      titleLabel.topAnchor.constraint(equalTo: iconWrap.bottomAnchor, constant: 18),
      titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
      titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),

      subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
      subtitleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
      subtitleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),

      hintLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
      hintLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
      hintLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
      hintLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -28),
    ])

    window.addSubview(cover)
    privacyCover = cover
  }

  private func revealWindow() {
    privacyCover?.removeFromSuperview()
    privacyCover = nil
  }
}
