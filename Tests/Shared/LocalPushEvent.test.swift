import HAKit
@testable import Shared
import XCTest

class LocalPushEventTests: XCTestCase {
    func testInvalid() {
        let data = HAData.empty
        XCTAssertThrowsError(try LocalPushEvent(data: data)) { error in
            XCTAssertEqual(error as? LocalPushEvent.LocalPushEventError, .invalidType)
        }
    }

    func testIdentifier() throws {
        let dataWithTag = HAData.dictionary([
            "message": "some_message",
            "data": [
                "tag": "some_tag",
            ],
        ])
        let dataWithoutTag = HAData.dictionary([
            "message": "some_message",
        ])
        let eventWithTag = try LocalPushEvent(data: dataWithTag)
        XCTAssertEqual(eventWithTag.identifier, "some_tag")
        let eventWithoutTag = try LocalPushEvent(data: dataWithoutTag)
        XCTAssertFalse(eventWithoutTag.identifier.isEmpty)
    }

    func testMinimal() {
        let event = LocalPushEvent(
            headers: [:],
            payload: [
                "aps": [
                    "alert": [
                        "body": "some_body",
                    ],
                ],
            ]
        )
        let content = event.content
        XCTAssertTrue(content.title.isEmpty)
        XCTAssertTrue(content.subtitle.isEmpty)
        XCTAssertEqual(content.body, "some_body")
        XCTAssertTrue(content.threadIdentifier.isEmpty)
        XCTAssertNil(content.badge)
        XCTAssertTrue(content.categoryIdentifier.isEmpty)
        XCTAssertNil(content.sound)
        XCTAssertEqual(Set(content.userInfo.keys), Set(["aps"]))
        #if compiler(>=5.5)
        if #available(iOS 15, watchOS 8, *) {
            XCTAssertEqual(content.interruptionLevel, .active)
        }
        #endif
    }

    func testFullWithoutSound() {
        let event = LocalPushEvent(
            headers: [:],
            payload: [
                "aps": [
                    "alert": [
                        "title": "some_title",
                        "subtitle": "some_subtitle",
                        "body": "some_body",
                    ],
                    "thread-id": "some_thread_id",
                    "badge": 3,
                    "category": "some_category",
                    "interruption-level": "time-sensitive",
                ],
                "extra": true,
            ]
        )
        let content = event.content
        XCTAssertEqual(content.title, "some_title")
        XCTAssertEqual(content.subtitle, "some_subtitle")
        XCTAssertEqual(content.body, "some_body")
        XCTAssertEqual(content.threadIdentifier, "some_thread_id")
        XCTAssertEqual(content.badge, 3)
        XCTAssertEqual(content.categoryIdentifier, "some_category")
        XCTAssertEqual(Set(content.userInfo.keys), Set(["aps", "extra"]))
        #if compiler(>=5.5)
        if #available(iOS 15, watchOS 8, *) {
            XCTAssertEqual(content.interruptionLevel, .timeSensitive)
        }
        #endif
    }

    func testSoundNonCriticalNamed() {
        let possibleSounds: [Any] = [
            "some_sound",
            ["name": "some_sound"],
            // volume makes no difference for non-critical
            // so all volume values should be the same
            ["name": "some_sound", "volume": 1.0],
            ["name": "some_sound", "volume": 0.5],
            ["name": "some_sound", "volume": 0.0],
        ]

        for sound in possibleSounds {
            let event = LocalPushEvent(
                headers: [:],
                payload: [
                    "aps": [
                        "alert": [
                            "body": "some_body",
                        ],
                        "sound": sound,
                    ],
                ]
            )
            let content = event.content
            XCTAssertEqual(content.sound, .init(named: .init(rawValue: "some_sound")))
        }
    }

    func testSoundNonCriticalDefault() {
        let possibleSounds: [Any] = [
            "default",
            ["name": "default"],
            // volume makes no difference for non-critical
            // so all volume values should be the same
            ["name": "default", "volume": 1.0],
            ["name": "default", "volume": 0.5],
            ["name": "default", "volume": 0.0],
        ]

        for sound in possibleSounds {
            let event = LocalPushEvent(
                headers: [:],
                payload: [
                    "aps": [
                        "alert": [
                            "body": "some_body",
                        ],
                        "sound": sound,
                    ],
                ]
            )
            let content = event.content
            XCTAssertEqual(content.sound, .default)
        }
    }

    func testSoundCriticalNamed() throws {
        let possibleSounds: [Any] = [
            ["name": "some_sound", "critical": 1],
            ["name": "some_sound", "critical": true],
        ]

        for sound in possibleSounds {
            let event = LocalPushEvent(
                headers: [:],
                payload: [
                    "aps": [
                        "alert": [
                            "body": "some_body",
                        ],
                        "sound": sound,
                    ],
                ]
            )
            let content = event.content
            XCTAssertEqual(content.sound, .criticalSoundNamed(.init(rawValue: "some_sound")))
        }
    }

    func testSoundCriticalNamedLevel() {
        let possibleSounds: [[String: Any]] = [
            ["name": "some_sound", "critical": 1],
            ["name": "some_sound", "critical": true],
        ]

        for var sound in possibleSounds {
            for level in stride(from: 0.0, through: 1.0, by: 0.1) {
                sound["volume"] = level

                let event = LocalPushEvent(
                    headers: [:],
                    payload: [
                        "aps": [
                            "alert": [
                                "body": "some_body",
                            ],
                            "sound": sound,
                        ],
                    ]
                )
                XCTAssertEqual(
                    event.content.sound,
                    .criticalSoundNamed(.init(rawValue: "some_sound"), withAudioVolume: Float(level))
                )
            }
        }
    }

    func testSoundCriticalDefaultLevel() {
        let possibleSounds: [[String: Any]] = [
            ["name": "default", "critical": 1],
            ["name": "default", "critical": true],
            ["critical": 1],
            ["critical": true],
        ]

        for var sound in possibleSounds {
            for level in stride(from: 0.0, through: 1.0, by: 0.1) {
                sound["volume"] = level

                let event = LocalPushEvent(
                    headers: [:],
                    payload: [
                        "aps": [
                            "alert": [
                                "body": "some_body",
                            ],
                            "sound": sound,
                        ],
                    ]
                )
                XCTAssertEqual(
                    event.content.sound,
                    .defaultCriticalSound(withAudioVolume: Float(level))
                )
            }
        }
    }

    #if compiler(>=5.5)
    func testInterruptionLevels() throws {
        guard #available(iOS 15, watchOS 8, *) else {
            throw XCTSkip("not valid on this OS")
        }

        let levels: [String: UNNotificationInterruptionLevel] = [
            "passive": .passive,
            "active": .active,
            "time-sensitive": .timeSensitive,
            "critical": .critical,
            "random_value": .active,
        ]

        for (value, level) in levels {
            let event = LocalPushEvent(
                headers: [:],
                payload: [
                    "aps": [
                        "alert": [
                            "body": "some_body",
                        ],
                        "interruption-level": value,
                    ],
                ]
            )
            let content = event.content
            XCTAssertEqual(content.interruptionLevel, level)
        }
    }
    #endif
}
