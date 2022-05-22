import Foundation
import XCTest

class FailingURLAuthenticationChallengeSender: NSObject, URLAuthenticationChallengeSender {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {
        XCTFail()
    }

    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {
        XCTFail()
    }

    func cancel(_ challenge: URLAuthenticationChallenge) {
        XCTFail()
    }
}

extension SecTrust {
    private static func secTrust(with string: String) throws -> SecTrust {
        let certificateData = try XCTUnwrap(Data(base64Encoded: string, options: [.ignoreUnknownCharacters]))
        let certificate = try XCTUnwrap(SecCertificateCreateWithData(nil, certificateData as CFData))
        var secTrust: SecTrust?
        SecTrustCreateWithCertificates([certificate] as CFArray, nil, &secTrust)
        return try XCTUnwrap(secTrust)
    }

    func authenticationChallenge() -> URLAuthenticationChallenge {
        URLAuthenticationChallenge(
            protectionSpace: {
                let space = URLProtectionSpace(
                    host: "UnitTest.Example.com",
                    port: 443,
                    protocol: nil,
                    realm: nil,
                    authenticationMethod: NSURLAuthenticationMethodServerTrust
                )
                // no public method exists to construct with a SecTrust
                space.perform(Selector(("_setServerTrust:")), with: self)
                return space
            }(),
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: FailingURLAuthenticationChallengeSender()
        )
    }

    static var unitTestDotExampleDotCom1: SecTrust {
        get throws {
            try secTrust(with: """
                MIIFSjCCAzICCQCoZrGH86VmVzANBgkqhkiG9w0BAQsFADBnMQswCQYDVQQGEwJVVDELMAkGA1UECAwCVVQxEjAQBgNVBAcMCVVu
                aXQgVGVzdDELMAkGA1UECgwCVVQxCzAJBgNVBAsMAlVUMR0wGwYDVQQDDBRVbml0VGVzdC5FeGFtcGxlLmNvbTAeFw0yMjA1MjIw
                NTA4NTZaFw0yMzA1MjEwNTA4NTZaMGcxCzAJBgNVBAYTAlVUMQswCQYDVQQIDAJVVDESMBAGA1UEBwwJVW5pdCBUZXN0MQswCQYD
                VQQKDAJVVDELMAkGA1UECwwCVVQxHTAbBgNVBAMMFFVuaXRUZXN0LkV4YW1wbGUuY29tMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
                MIICCgKCAgEAqbr4PUsVuC6h+uW/L4to1iI4mXdblhZGOfiE+Yinfd+oyuY/9+aMm+1I4O/0bZ/bDfxAC8qq7gsicztehSUPwDN2
                WDRYe+Dv6TkK9vL6AgdLUW8KGPDgo5r2Xa6IY0n6xyqWj2GheifBtTZ6VG7y/ptkHvvBKO6DhOL1kGeZZUjncHXgIgySjBzEaGMu
                mquc2i10d7B7FXr70RTTr/gUFsokUpMQ2oQpD3y8yIrmtDhEoQYGqWVCaZxCWmLRw1AqqYA1TosnmIw77uRwhZBoeFF9JxoBEMAN
                BSmTYKbb6j1YH9AIQO7fAe5njWvQuomdMFUE18QKoC6Xxoy6HA0pPoElUL/46+OOO9oOQfCD9OkQAqtCS7ofErUo6b5Pj+mriFn0
                46EfXKkHWGwRwoPBDotxCiU56RDJNbsDec//QiwYTdM7hhyZR4mrPed/YbLxIggvHF80PosehYz/959Ubo3GSnJ8tmZFUleBW6Ax
                YgJ+i8qWgvqyCTq/3/D2o+3Xy9yvx1ArsV8WscqQjJSAlRKyY30V4d0DCgwGJSlBfYFkTnMYXAnk4WGnZh0+r78jPENpsm4mEC1C
                dvOXq/ksCX2mLUVNRKsMzY6zXCD6uKwZwGPPMK6QMh+0P26jkxa5MoIP9JQ7m/sDozJiUZB3rkqkfSHHApElZ/9kAroo9wECAwEA
                ATANBgkqhkiG9w0BAQsFAAOCAgEAc4MULk5StQhiLxA0A1q/EubzOWzKvCzC3Xu3NKkyGZtJj4txXFGTLVSLLv8YxCiswg2VF0AL
                EGeMIKfUdXUlx8ZbvTLjQw09jaktev8EV2/wk1BiJNbXDbfBwXW7pSmIQUwC8UUiQhaTNkMpiyG/KMvOqtf4oilYDC4fiNDQ0RLr
                U5n2JqvMIF90YOQZLWRDE7gyI452g3dAen4MHE9CAd/eJIilKw1zE4kx1Tq6sqYrU88h23kJaQ/p+TfEzEFPkF08e/8WhgvKiUyM
                krHy3ng4VxXsHK931o6kuF3nWrb6zpqCzwuU/lAL6S9v26bDi3rZZy7UMj+16LiWA3A16VxK/D9WlPHoQUjZVt8Kx8RJcunbIWnD
                omndP+B1mYsaTAHpsJmmbwI5rrkHrDjc/sFsiaSm0vM0yec+VO7YceGWZ4wwjfU+TNuaE7sk9c3y4e/siQGU1leSLbHifAOJq3rP
                jDsspDOMwS5iD+ofzFqJE61MBOygqBf6kz0nCQwWOUR77uCXO4goN/Jjkta7PmIOCnRwo8uP0/gXquCtyZtXlBPhLUYVpAvPutLX
                uu1ix+3LYmd0B7J0hup/qZIlYuXoarfd909lBj2nfmrS2R8sF205cBQgPZU7gmtoPFby/LcQ/SydLRhj2n3zvpRC+uKIQkzJAwmr
                PufRFkjYWLE=
            """)
        }
    }

    static var unitTestDotExampleDotCom2: SecTrust {
        get throws {
            try secTrust(with: """
                MIIFSjCCAzICCQDbnKTUkLw1IDANBgkqhkiG9w0BAQsFADBnMQswCQYDVQQGEwJVVDELMAkGA1UECAwCVVQxEjAQBgNVBAcMCVVu
                aXQgVGVzdDELMAkGA1UECgwCVVQxCzAJBgNVBAsMAlVUMR0wGwYDVQQDDBRVbml0VGVzdC5FeGFtcGxlLmNvbTAeFw0yMjA1MjIw
                NTA5MzBaFw0yMzA1MjEwNTA5MzBaMGcxCzAJBgNVBAYTAlVUMQswCQYDVQQIDAJVVDESMBAGA1UEBwwJVW5pdCBUZXN0MQswCQYD
                VQQKDAJVVDELMAkGA1UECwwCVVQxHTAbBgNVBAMMFFVuaXRUZXN0LkV4YW1wbGUuY29tMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
                MIICCgKCAgEA4LVVbRwLUf9sXmO6a/9rftFpV5E9MMSI5aRj73fjcyfmf1v7+Lg4LqS47/11/uSxVzbRP9awHASdoVvzSwqITLDU
                agVzK8fK/yDRqq383mfXEZEgQKaWfxMVDm9ywT5MyYkucORGn3GrooG9GdHPSiMtpnsyN+TsInuzMP3Ou+2nr0Tg1CJodJfaq7Wt
                MlVvCwEc3xAcdrqmvtqDk0AWSf04UZIFseeM7GI9wcD3K8lYB4aiMMO8JgCbyH+NYFUXVpUdmIkzKqyMFKjzU9cfcKGMhZ3MnvO2
                zb+uLQdsvO2/iGN+L6XsE2qfG66ZnVUX56PvCz9NIWU6gYszvEOuj2yJitvt8QDO+ewJ0jrBWygdv1tsoeQR/2RubrJ4VO8nnWXm
                lDZiIWuQTmJ+T5A4YckArux7I7lrGxXZj0J8jL4T4XxHp8XRSNAohweP63p9DhcpJCPZA02IzleieJxHlrWJIm0WVUOTZUzICHPX
                ObVTyD+CPZKt172oR4E4BIgGgBu+pSi8CLdSXliFtCVssy3QpaAqyhjuHZvWM41m0jIbzZjCZf9dqlqCZX7Iqpnd2IAC1a1ZR47l
                nNHqehJbSu1b03phAz/Pq29WEEnHMHdwgMfE8m6a0qsL0q4z01M9ekrJ97w9SbGHxlgwAnlAb9/EJCJP+GP2mG/QN6jzz7UCAwEA
                ATANBgkqhkiG9w0BAQsFAAOCAgEAKfBnBPtOGy22pjnGYzYhxBHju4tfb9PDMcnhhGyKYtnu+M6GSJeaRhOXHQo0HdILnyhE7fs1
                S1rD7P1FZG338idf8c6EepbysxlQJXweOIrDuLQyHz+rvJFVJKZO4ry+pCTgVlZ0gCDalm9F91Zmu4rAtcpZn0SFSjytpw4Oz8Ny
                uuxdJjX1vn22JNd/VmqMbGFKbqsVB1tjJXoEUqU4WkW6oxx191k86NT6aM/W3deHMoaqtSPXIR39JuhfKsQRmLYQzjf4/3ydbOS8
                mxEgUrzGAbW4An6AuocFYHxvFO1r57/9NC0y1r0BWNRDho3isRAABgDC71wZf6f+W1HXdicRZe8c76xHMeUb85YrKFm/plRavzuP
                5l0TKM/04RJh/1ahitZjDe94AmHuEM2eE7/WShRvf8wlgm2/8Zhy/kKZKo5O/8nAtIcfxRFdQd2SyoUHLHrzhs/nHyIPBKjsKzVN
                e4UZwhLP/EXWC3aRLKrjBzglwy3WMGBxmeV7to0a9P58JG3HLumaw1L2KDvRT2g+SDX/+z1ZesdOq3NgcIhQa9ukViPNA1WbLM3+
                laDS8AFOvxKa5jDcIIr96WPCcsu4mE1hmSTz9o7wT6vLNziXd9nhyEMJ+Ln/bRhef+OZ/1VPK76XaeAmsdFVBpjFOXSL2IS8650y
                z/KgFzrCLbk=
            """)
        }
    }

    static var unitTestDotExampleDotCom3: SecTrust {
        get throws {
            try secTrust(with: """
                MIIFPDCCAyQCCQChhRw3eVsWujANBgkqhkiG9w0BAQsFADBgMQswCQYDVQQGEwJVVDELMAkGA1UECAwCVVQxCzAJBgNVBAcMAlVU
                MQswCQYDVQQKDAJVVDELMAkGA1UECwwCVVQxHTAbBgNVBAMMFFVuaXRUZXN0LkV4YW1wbGUuY29tMB4XDTIyMDUyMjA1MTIzOVoX
                DTIzMDUyMTA1MTIzOVowYDELMAkGA1UEBhMCVVQxCzAJBgNVBAgMAlVUMQswCQYDVQQHDAJVVDELMAkGA1UECgwCVVQxCzAJBgNV
                BAsMAlVUMR0wGwYDVQQDDBRVbml0VGVzdC5FeGFtcGxlLmNvbTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOFXnZF/
                KNQLNTZdZJZodpl85iaxw/w5YSF6lKc6Dx3IU+4KI6oFK9VBdGMLxYs9OjbUoEGzDtAot0+SN2ay4c7080zSuRIdB9E9fAnl9mzR
                huitAmGly+e88I9NFQMLeFWCshth02rghkYi6tVuSP8G7koIcOMDGEel00sb9N3F1gNIlFz85LjOD8PHJNkcPdSyZWuf7o7HBCf+
                QRM5eQSl6/vpsWgQgRucRZkx/GV88ltoaQ1s5nuIQdIE85UDSNIAxySkjpFFFzEf/CaXcgL4hofats089a6NEP82kWIK4Px4QIqX
                VTDC1G7rcWMUU4963thK08dV6Gjv07vTDRZpTIQZjrSEiep3uJ5gHdu73LYm2NdEEUkb34ZfcyaFxaswyvMN+O83hASEs5erbqTT
                xyuqrpv3vHSKdyatKPA3tvVs1DedwBalbXB5wVJOnmTf2waYXnCYZJqV1YuAHXHmWomPZEKHk6oqS7+PWblsKNoaorpEscNrS4eJ
                BByMPvFnYaAaP5jT5j3DKrsDudRUCtIVsNxEzOZiGqBeylSbtWh4PL9nyrvlRIiWzLl82pgJYm1d59p+qaGCDozMRVKXgmIQczLA
                /N36SGCpfdEGbK0kisWqKmzr6Ox/IPB/2VNUMStvCb66hpndTFIJFPtWabvaOPDKihNOiXo5JPJVAgMBAAEwDQYJKoZIhvcNAQEL
                BQADggIBACELquzqSyuCIuq097KEU+2hMouRjMsPTLr5mL5TRlndxuYWvq2cj3Ke4XElEjVzBbeC03RZEgdwvrhzjqWlHLu7z7T8
                kNd8RbVkDF0/o7uPV6I+Bl0n1jJYNSvEzPs01iBzSPq8SjGZkNLXwyRwvaIPZeNFcxTOHuOzNqZJQONzqs4QySvcV80LvNxYc0uC
                b5JH44PIRqd5ftnbuW/Zlvz0EsDlepnfR4zKyVR4NY+uD9jRBvLr3VO414ovBUKP0Qc5mlNiksULwsHVPyoadYfFvNljcy8n+TNW
                0M7Au8IN08ExJG9OxLOfiybxHGcO+3vlEtDPnz9fvwRN0FP6oNLQSx2O7G7DQD5g7nugjQyVzOtxB+74ZNaeCZr6ele0bjbI9HiS
                3QyiTq7m/BOnr0XUnfV0Gf3bYsHBvZCLOgtsQzkxmRiQlrpmsJXPU/G8qtwFAZzszSkTafryjaHzhDFk24K8ek1kWnbgdq7vC1Lc
                0U5tXomvu+dZ+ceJYkPNb7isuoFw3O92fYvuiiqvY6DcBs+FU9BdWPXGVA/LRod/yuD3sxptwTGXV1K4+vGd46AZKlPDAVJPLMXu
                SekCb5dzX84jBaMF5r8VPOez4d5ou+sZi3tOtZQr5LoXbxQDMIaosExdWQ/KN4nTHiG295gBIohrcmG9ij29CFAUQucf
            """)
        }
    }
}
