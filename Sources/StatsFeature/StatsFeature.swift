import ComposableArchitecture
import LocalDatabaseClient
import SharedModels
import Styleguide
import SwiftUI
import VocabFeature

public struct StatsState: Equatable {
  public var averageWordLength: Double?
  public var gamesPlayed: Int
  public var highestScoringWord: LocalDatabaseClient.Stats.Word?
  public var highScoreTimed: Int?
  public var highScoreUnlimited: Int?
  public var longestWord: String?
  public var route: Route?
  public var secondsPlayed: Int
  public var wordsFound: Int

  public enum Route: Equatable {
    case vocab(VocabState)

    public enum Tag: Int {
      case vocab
    }

    var tag: Tag {
      switch self {
      case .vocab:
        return .vocab
      }
    }
  }

  public init(
    averageWordLength: Double? = nil,
    gamesPlayed: Int = 0,
    highestScoringWord: LocalDatabaseClient.Stats.Word? = nil,
    highScoreTimed: Int? = nil,
    highScoreUnlimited: Int? = nil,
    longestWord: String? = nil,
    route: Route? = nil,
    secondsPlayed: Int = 0,
    //    vocab: VocabState? = nil,
    wordsFound: Int = 0
  ) {
    self.averageWordLength = averageWordLength
    self.gamesPlayed = gamesPlayed
    self.highestScoringWord = highestScoringWord
    self.highScoreTimed = highScoreTimed
    self.highScoreUnlimited = highScoreUnlimited
    self.longestWord = longestWord
    self.route = route
    self.secondsPlayed = secondsPlayed
    //    self.vocab = vocab
    self.wordsFound = wordsFound
  }
}

public enum StatsAction: Equatable {
  case backButtonTapped
  case onAppear
  case setNavigation(tag: StatsState.Route.Tag?)
  case statsResponse(Result<LocalDatabaseClient.Stats, NSError>)
  case vocab(VocabAction)
}

public struct StatsEnvironment {
  var database: LocalDatabaseClient

  public init(database: LocalDatabaseClient) {
    self.database = database
  }
}

public let statsReducer: Reducer<StatsState, StatsAction, StatsEnvironment> = .combine(
  vocabReducer
    ._pullback(
      state: (\StatsState.route).appending(path: /StatsState.Route.vocab),
      action: /StatsAction.vocab,
      environment: { VocabEnvironment(database: $0.database) }
    ),

  .init { state, action, environment in
    switch action {
    case .backButtonTapped:
      return .none

    case .onAppear:
      // TODO: should we do this work on background thread?
      return environment.database.fetchStats
        .mapError { $0 as NSError }
        .catchToEffect()
        .map(StatsAction.statsResponse)

    case let .statsResponse(.failure(error)):
      // TODO
      return .none

    case let .statsResponse(.success(stats)):
      state.averageWordLength = stats.averageWordLength
      state.gamesPlayed = stats.gamesPlayed
      state.highestScoringWord = stats.highestScoringWord
      state.highScoreTimed = stats.highScoreTimed
      state.highScoreUnlimited = stats.highScoreUnlimited
      state.longestWord = stats.longestWord
      state.secondsPlayed = stats.secondsPlayed
      state.wordsFound = stats.wordsFound
      return .none

    case .setNavigation(tag: .vocab):
      state.route = .vocab(.init())
      return .none

    case .setNavigation(tag: .none):
      state.route = nil
      return .none

    case .vocab:
      return .none
    }
  }
)

public struct StatsView: View {
  let store: Store<StatsState, StatsAction>
  @ObservedObject var viewStore: ViewStore<StatsState, StatsAction>

  public init(store: Store<StatsState, StatsAction>) {
    self.store = store
    self.viewStore = ViewStore(store)
  }

  public var body: some View {
    SettingsForm {
      SettingsRow {
        HStack {
          Text("Games played")
          Spacer()
          Text("\(self.viewStore.gamesPlayed)")
            .foregroundColor(.isowordsOrange)
        }
        .adaptiveFont(.matterMedium, size: 16)
      }

      SettingsRow {
        VStack(alignment: .leading) {
          Text("Top scores")
            .adaptiveFont(.matterMedium, size: 16)

          VStack(alignment: .leading) {
            HStack {
              Text("Timed")
              Spacer()
              Group {
                if let highScoreTimed = self.viewStore.highScoreTimed {
                  Text("\(highScoreTimed)")
                } else {
                  Text("none")
                }
              }
              .foregroundColor(.isowordsOrange)
            }
            Divider()
            HStack {
              Text("Unlimited")
              Spacer()
              Group {
                if let highScoreUnlimited = self.viewStore.highScoreUnlimited {
                  Text("\(highScoreUnlimited)")
                } else {
                  Text("none")
                }
              }
              .foregroundColor(.isowordsOrange)
            }
          }
          .adaptiveFont(.matterMedium, size: 16)
          .padding([.leading, .top])
        }
      }

      SettingsRow {
        NavigationLink(
          destination: IfLetStore(
            self.store.scope(
              state: (\StatsState.route).appending(path: /StatsState.Route.vocab).extract(from:),
              action: StatsAction.vocab
            ),
            then: VocabView.init(store:)
          ),
          tag: StatsState.Route.Tag.vocab,
          selection: self.viewStore.binding(
            get: \.route?.tag,
            send: StatsAction.setNavigation(tag:)
          )
        ) {
          HStack {
            Text("Words found")
            Spacer()
            Group {
              Text("\(self.viewStore.wordsFound)")
              Image(systemName: "arrow.right")
            }
            .foregroundColor(.isowordsOrange)
          }
          .adaptiveFont(.matterMedium, size: 16)
          .background(Color.adaptiveWhite)
        }
        .buttonStyle(PlainButtonStyle())
      }

      if let highestScoringWord = self.viewStore.highestScoringWord {
        SettingsRow {
          VStack(alignment: .trailing, spacing: 12) {
            HStack {
              Text("Best word")
                .adaptiveFont(.matterMedium, size: 16)
              Spacer()
              HStack(alignment: .top, spacing: 0) {
                Text(highestScoringWord.letters.capitalized)
                  .adaptiveFont(.matterMedium, size: 16)

                Text("\(highestScoringWord.score)")
                  .padding(.top, -4)
                  .adaptiveFont(.matterMedium, size: 12)
              }
              .foregroundColor(.isowordsOrange)
            }
          }
        }
      }

      SettingsRow {
        HStack {
          Text("Time played")
          Spacer()
          Text(timePlayed(seconds: self.viewStore.secondsPlayed))
            .foregroundColor(.isowordsOrange)
        }
        .adaptiveFont(.matterMedium, size: 16)
      }
    }
    .onAppear { self.viewStore.send(.onAppear) }
    .navigationStyle(title: Text("Stats"))
  }
}

private func timePlayed(seconds: Int) -> LocalizedStringKey {
  let hours = seconds / 60 / 60
  let minutes = (seconds / 60) % 60
  return "\(hours)h \(minutes)m"
}

#if DEBUG
  import SwiftUIHelpers

  @testable import LocalDatabaseClient

  struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
      Preview {
        NavigationView {
          StatsView(
            store: Store(
              initialState: StatsState(
                averageWordLength: 5,
                gamesPlayed: 1234,
                highestScoringWord: .init(letters: "ENFEEBLINGS", score: 1022),
                longestWord: "ENFEEBLINGS",
                secondsPlayed: 42000,
                wordsFound: 200
              ),
              reducer: statsReducer,
              environment: .init(
                database: .noop
              )
            )
          )
          .navigationBarHidden(true)
        }
      }
    }
  }
#endif
