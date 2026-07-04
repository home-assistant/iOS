import Foundation
import SFSafeSymbols

public extension MaterialDesignIcons {
    /// An SF Symbol that is visually or semantically similar to this Material Design icon.
    ///
    /// The mapping is a best-effort, hand-curated equivalence: it prefers the closest 1:1 match the
    /// running OS supports (many home-related SF Symbols only exist since iOS 16/17) and falls back
    /// to `.questionmarkCircle` when there is no reasonable equivalent.
    var similarSFSymbol: SFSymbol {
        if #available(iOS 17, watchOS 10, macOS 14, *), let symbol = sfSymbols5Match {
            return symbol
        }
        if #available(iOS 16, watchOS 9, macOS 13, *), let symbol = sfSymbols4Match {
            return symbol
        }
        return sfSymbols3Match ?? .questionmarkCircle
    }
}

private extension MaterialDesignIcons {
    /// Matches that require SF Symbols 5 (iOS 17, watchOS 10, macOS 14).
    @available(iOS 17, watchOS 10, macOS 14, *)
    var sfSymbols5Match: SFSymbol? {
        switch self {
        case .fanIcon, .fanSpeed1Icon, .fanSpeed2Icon, .fanSpeed3Icon: return .fan
        case .fanAutoIcon: return .fanBadgeAutomatic
        case .truckIcon, .truckDeliveryIcon, .truckFastIcon, .truckOutlineIcon: return .truckBox
        case .batteryIcon, .battery90Icon, .batteryHighIcon: return .battery100percent
        case .battery70Icon, .battery80Icon: return .battery75percent
        case .battery40Icon, .battery50Icon, .battery60Icon, .batteryMediumIcon: return .battery50percent
        case .battery10Icon, .battery20Icon, .battery30Icon, .batteryLowIcon: return .battery25percent
        case .batteryOutlineIcon, .batteryAlertIcon, .batteryOffIcon: return .battery0percent
        case .batteryChargingIcon, .batteryChargingHighIcon, .batteryCharging100Icon: return .battery100percentBolt
        case .consoleIcon, .consoleLineIcon: return .appleTerminal
        case .speedometerIcon, .speedometerMediumIcon, .speedometerSlowIcon: return .gaugeWithNeedle
        case .gaugeIcon, .gaugeFullIcon, .gaugeLowIcon, .gaugeEmptyIcon: return .gaugeWithNeedle
        case .storeIcon, .storeOutlineIcon, .storefrontOutlineIcon: return .storefront
        case .evStationIcon: return .evCharger
        case .flaskIcon, .flaskOutlineIcon, .flaskEmptyIcon, .flaskEmptyOutlineIcon: return .flask
        case .eraserIcon: return .eraser
        case .televisionOffIcon, .televisionClassicOffIcon: return .tvSlash
        case .calendarCheckIcon, .calendarCheckOutlineIcon: return .calendarBadgeCheckmark
        case .hangerIcon: return .hanger
        case .heatingCoilIcon, .heatWaveIcon: return .heatWaves
        case .accountOffIcon, .accountOffOutlineIcon: return .personSlash
        case .dogIcon, .dogSideIcon, .dogServiceIcon: return .dog
        case .catIcon: return .cat
        case .sunglassesIcon: return .sunglasses
        case .shoeSneakerIcon, .shoeFormalIcon, .shoeHeelIcon: return .shoe
        default: return nil
        }
    }

    /// Matches that require SF Symbols 4 (iOS 16, watchOS 9, macOS 13).
    @available(iOS 16, watchOS 9, macOS 13, *)
    var sfSymbols4Match: SFSymbol? {
        switch self {
        // MARK: Lighting
        case .lightbulbGroupIcon, .lightbulbGroupOutlineIcon, .lightbulbMultipleIcon: return .lightbulb2
        case .lightbulbMultipleOutlineIcon: return .lightbulb2
        case .ceilingLightIcon, .ceilingLightOutlineIcon, .ceilingLightMultipleIcon: return .lampCeiling
        case .ceilingLightMultipleOutlineIcon: return .lampCeiling
        case .floorLampIcon, .floorLampOutlineIcon, .floorLampDualIcon: return .lampFloor
        case .floorLampDualOutlineIcon, .floorLampTorchiereIcon: return .lampFloor
        case .deskLampIcon, .deskLampOnIcon: return .lampDesk
        case .lampIcon, .lampOutlineIcon, .lampsIcon, .lampsOutlineIcon: return .lampTable
        case .chandelierIcon: return .chandelier
        case .ledStripIcon, .ledStripVariantIcon: return .lightStrip2
        case .lightSwitchIcon: return .lightswitchOn
        case .lightSwitchOffIcon: return .lightswitchOff
        case .trackLightIcon: return .lightOverheadRight
        case .alarmLightIcon, .alarmLightOutlineIcon: return .lightBeaconMax
        case .spotlightBeamIcon: return .lightBeaconMax

        // MARK: Climate & air
        case .thermometerIcon, .thermostatIcon, .thermostatBoxIcon: return .thermometerMedium
        case .thermometerHighIcon: return .thermometerHigh
        case .thermometerLowIcon: return .thermometerLow
        case .temperatureCelsiusIcon, .temperatureFahrenheitIcon, .temperatureKelvinIcon: return .thermometerMedium
        case .homeThermometerIcon, .homeThermometerOutlineIcon: return .thermometerMedium
        case .airConditionerIcon: return .airConditionerHorizontal
        case .hvacIcon, .hvacOffIcon: return .airConditionerVertical
        case .airFilterIcon, .airPurifierIcon: return .airPurifier
        case .fanOffIcon: return .fanOscillation
        case .ceilingFanIcon: return .fanCeiling
        case .ceilingFanLightIcon: return .fanAndLightCeiling
        case .radiatorIcon, .radiatorOffIcon, .radiatorDisabledIcon: return .heaterVertical
        case .waterBoilerIcon, .waterBoilerOffIcon, .waterBoilerAlertIcon: return .heaterVertical
        case .fireplaceIcon, .fireplaceOffIcon: return .fireplace
        case .airHumidifierIcon: return .humidifier
        case .airHumidifierOffIcon: return .humidifierFill

        // MARK: Sensors & safety
        case .smokeDetectorIcon, .smokeDetectorVariantIcon, .smokeDetectorOutlineIcon: return .sensor
        case .smokeDetectorAlertIcon, .smokeDetectorVariantAlertIcon: return .sensorFill
        case .motionSensorIcon: return .sensorTagRadiowavesForward
        case .moleculeCo2Icon: return .carbonDioxideCloud
        case .moleculeCoIcon: return .carbonMonoxideCloud
        case .cctvIcon: return .webCamera
        case .webcamIcon: return .webCamera
        case .lockAlertIcon, .lockAlertOutlineIcon: return .lockTrianglebadgeExclamationmark
        case .keyWirelessIcon: return .keyRadiowavesForward

        // MARK: Doors, windows & covers
        case .doorIcon, .doorClosedIcon, .doorClosedLockIcon: return .doorLeftHandClosed
        case .doorOpenIcon: return .doorLeftHandOpen
        case .doorSlidingIcon: return .doorSlidingLeftHandClosed
        case .doorSlidingOpenIcon: return .doorSlidingLeftHandOpen
        case .garageIcon, .garageVariantIcon, .garageLockIcon: return .doorGarageClosed
        case .garageOpenIcon, .garageOpenVariantIcon: return .doorGarageOpen
        case .garageAlertIcon, .garageAlertVariantIcon: return .doorGarageClosedTrianglebadgeExclamationmark
        case .windowClosedIcon, .windowClosedVariantIcon: return .windowVerticalClosed
        case .windowOpenIcon, .windowOpenVariantIcon: return .windowVerticalOpen
        case .windowShutterIcon, .windowShutterAlertIcon, .windowShutterSettingsIcon: return .windowShadeClosed
        case .windowShutterOpenIcon: return .windowShadeOpen
        case .blindsIcon, .blindsHorizontalClosedIcon: return .blindsHorizontalClosed
        case .blindsOpenIcon, .blindsHorizontalIcon: return .blindsHorizontalOpen
        case .blindsVerticalClosedIcon: return .blindsVerticalClosed
        case .blindsVerticalIcon: return .blindsVerticalOpen
        case .rollerShadeIcon: return .rollerShadeOpen
        case .rollerShadeClosedIcon: return .rollerShadeClosed
        case .curtainsIcon: return .curtainsOpen
        case .curtainsClosedIcon: return .curtainsClosed
        case .stairsIcon, .stairsUpIcon, .stairsDownIcon: return .stairs

        // MARK: Rooms, furniture & appliances
        case .sofaIcon, .sofaOutlineIcon: return .sofa
        case .sofaSingleIcon, .sofaSingleOutlineIcon: return .chairLounge
        case .chairRollingIcon, .seatIcon, .seatOutlineIcon: return .chair
        case .tableFurnitureIcon: return .tableFurniture
        case .stoveIcon, .gasBurnerIcon: return .stove
        case .toasterOvenIcon: return .oven
        case .microwaveIcon: return .microwave
        case .fridgeIcon, .fridgeOutlineIcon, .fridgeVariantIcon: return .refrigerator
        case .fridgeIndustrialIcon, .fridgeIndustrialOutlineIcon: return .refrigerator
        case .dishwasherIcon, .dishwasherAlertIcon, .dishwasherOffIcon: return .dishwasher
        case .washingMachineIcon, .washingMachineAlertIcon, .washingMachineOffIcon: return .washer
        case .tumbleDryerIcon, .tumbleDryerAlertIcon, .tumbleDryerOffIcon: return .dryer
        case .countertopIcon, .countertopOutlineIcon: return .sink
        case .showerIcon: return .shower
        case .showerHeadIcon: return .showerHandheld
        case .bathtubIcon, .bathtubOutlineIcon, .hotTubIcon: return .bathtub
        case .toiletIcon: return .toilet
        case .teaIcon, .teaOutlineIcon, .beerIcon, .beerOutlineIcon: return .mug
        case .carrotIcon: return .carrot
        case .cakeVariantIcon, .cakeVariantOutlineIcon, .cakeIcon: return .birthdayCake

        // MARK: Water & outdoor
        case .pipeValveIcon, .valveIcon: return .spigot
        case .waterPumpIcon: return .spigot
        case .sprinklerIcon, .sprinklerFireIcon: return .sprinkler
        case .sprinklerVariantIcon: return .sprinklerAndDroplets
        case .wavesIcon: return .waterWaves
        case .poolIcon: return .figurePoolSwim
        case .swimIcon: return .figurePoolSwim
        case .treeIcon, .treeOutlineIcon, .pineTreeIcon, .forestIcon, .palmTreeIcon: return .tree
        case .flowerIcon, .flowerOutlineIcon, .flowerTulipIcon, .flowerTulipOutlineIcon: return .cameraMacro
        case .beachIcon, .umbrellaBeachIcon, .umbrellaBeachOutlineIcon: return .beachUmbrella
        case .tentIcon: return .tent

        // MARK: Power
        case .powerSocketIcon: return .poweroutletStrip
        case .powerSocketUsIcon: return .poweroutletTypeB
        case .powerSocketEuIcon, .powerSocketDeIcon: return .poweroutletTypeF
        case .powerSocketUkIcon: return .poweroutletTypeG
        case .powerSocketAuIcon: return .poweroutletTypeI
        case .powerSocketFrIcon: return .poweroutletTypeE
        case .powerSocketJpIcon: return .poweroutletTypeA
        case .powerSocketChIcon: return .poweroutletTypeJ
        case .powerSocketItIcon: return .poweroutletTypeL

        // MARK: People & figures
        case .accountClockIcon, .accountClockOutlineIcon: return .personBadgeClock
        case .accountKeyIcon, .accountKeyOutlineIcon: return .personBadgeKey
        case .accountChildIcon, .accountChildOutlineIcon: return .figureAndChildHoldinghands
        case .accountChildCircleIcon: return .figureAndChildHoldinghands
        case .runIcon, .runFastIcon: return .figureRun
        case .hikingIcon: return .figureHiking
        case .wheelchairIcon, .wheelchairAccessibilityIcon: return .figureRoll
        case .babyCarriageIcon: return .stroller
        case .teddyBearIcon: return .teddybear
        case .exitRunIcon: return .figureWalkDeparture
        case .locationEnterIcon: return .figureWalkArrival
        case .locationExitIcon: return .figureWalkDeparture

        // MARK: Devices & tech
        case .routerIcon, .routerWirelessIcon, .routerNetworkIcon: return .wifiRouter
        case .routerWirelessOffIcon: return .wifiRouter
        case .accessPointIcon, .accessPointNetworkIcon: return .wifiRouter
        case .remoteIcon: return .avRemote
        case .messageProcessingIcon, .messageProcessingOutlineIcon: return .ellipsisMessage
        case .commentQuestionIcon, .commentQuestionOutlineIcon: return .questionmarkBubble

        // MARK: Vehicles & transport
        case .roadIcon, .roadVariantIcon, .highwayIcon: return .roadLanes
        case .parkingIcon: return .parkingsign
        case .sailBoatIcon: return .sailboat
        case .skiIcon: return .figureSkiingDownhill
        case .snowboardIcon: return .figureSnowboarding

        // MARK: Sports & leisure
        case .dumbbellIcon: return .dumbbell
        case .weightLifterIcon: return .figureStrengthtrainingTraditional
        case .yogaIcon, .meditationIcon: return .figureMindAndBody
        case .basketballIcon: return .basketball
        case .footballIcon, .footballAustralianIcon: return .football
        case .tennisIcon, .tennisBallIcon: return .tennisball
        case .volleyballIcon: return .volleyball
        case .rugbyIcon: return .figureRugby
        case .hockeyPuckIcon: return .hockeyPuck
        case .cricketIcon: return .cricketBall
        case .golfIcon: return .figureGolf
        case .bowlingIcon: return .figureBowling
        case .balloonIcon: return .balloon
        case .partyPopperIcon: return .partyPopper

        // MARK: Animals & nature
        case .birdIcon: return .bird
        case .fishIcon: return .fish
        case .virusIcon, .virusOutlineIcon, .bacteriaIcon, .bacteriaOutlineIcon: return .allergens

        // MARK: Misc objects
        case .wrenchIcon, .wrenchOutlineIcon: return .wrenchAdjustable
        case .pencilRulerIcon: return .pencilAndRuler
        case .bagPersonalIcon, .bagPersonalOutlineIcon: return .backpack
        case .medalIcon, .medalOutlineIcon: return .medal
        case .compassIcon, .compassOutlineIcon: return .locationNorthCircle
        case .flagCheckeredIcon: return .flagCheckered
        case .robotIcon, .robotOutlineIcon: return .gearshapeArrowTriangle2Circlepath

        // MARK: Older-OS fallbacks for SF Symbols 5 matches
        case .fanIcon, .fanSpeed1Icon, .fanSpeed2Icon, .fanSpeed3Icon, .fanAutoIcon: return .fanOscillation
        case .speedometerIcon, .speedometerMediumIcon, .speedometerSlowIcon: return .dialMedium
        case .gaugeIcon, .gaugeFullIcon, .gaugeLowIcon, .gaugeEmptyIcon: return .dialMedium
        case .batteryIcon, .battery90Icon, .batteryHighIcon, .batteryMediumIcon: return .batteryblock
        case .battery70Icon, .battery80Icon, .battery40Icon, .battery50Icon, .battery60Icon: return .batteryblock
        case .battery10Icon, .battery20Icon, .battery30Icon, .batteryLowIcon: return .batteryblock
        case .batteryOutlineIcon, .batteryAlertIcon, .batteryOffIcon: return .batteryblock
        case .heatingCoilIcon, .heatWaveIcon: return .heaterVertical
        case .flashAlertIcon: return .boltTrianglebadgeExclamationmark
        case .volumePlusIcon: return .speakerPlus
        case .volumeMinusIcon: return .speakerMinus
        case .signalIcon, .signalCellular1Icon, .signalCellular2Icon: return .cellularbars
        case .signalCellular3Icon, .signalCellularOutlineIcon: return .cellularbars
        case .clipboardIcon, .clipboardOutlineIcon: return .clipboard
        case .clipboardTextIcon, .clipboardTextOutlineIcon, .clipboardListIcon: return .clipboard
        case .trophyIcon, .trophyOutlineIcon, .trophyAwardIcon, .trophyVariantIcon: return .trophy
        case .needleIcon: return .syringe
        case .glassWineIcon, .glassCocktailIcon: return .wineglass
        case .bottleWineIcon, .bottleWineOutlineIcon: return .wineglass
        default: return nil
        }
    }

    /// Matches available from SF Symbols 3 and earlier (the iOS 15 / watchOS 8 baseline).
    var sfSymbols3Match: SFSymbol? {
        switch self {
        // MARK: Home
        case .homeIcon, .homeOutlineIcon, .homeVariantIcon, .homeVariantOutlineIcon: return .house
        case .homeAssistantIcon, .homeAutomationIcon, .homeAccountIcon, .homeHeartIcon: return .house
        case .homeCircleIcon, .homeCircleOutlineIcon: return .houseCircle
        case .homeCityIcon, .homeCityOutlineIcon: return .building2
        case .homeMapMarkerIcon: return .house
        case .officeBuildingIcon, .officeBuildingOutlineIcon, .domainIcon: return .building2
        case .homeGroupIcon: return .house

        // MARK: Lighting (baseline)
        case .lightbulbIcon, .lightbulbOutlineIcon, .lightbulbVariantIcon: return .lightbulb
        case .lightbulbVariantOutlineIcon, .lightbulbCflIcon, .lightbulbCflOffIcon: return .lightbulb
        case .lightbulbOnIcon, .lightbulbOnOutlineIcon: return .lightbulbFill
        case .lightbulbOffIcon, .lightbulbOffOutlineIcon: return .lightbulbSlash
        case .lightbulbGroupOffIcon, .lightbulbGroupOffOutlineIcon: return .lightbulbSlash
        case .flashlightIcon: return .flashlightOnFill
        case .flashlightOffIcon: return .flashlightOffFill
        case .candleIcon: return .flame

        // MARK: Switches & power (baseline)
        case .toggleSwitchIcon, .toggleSwitchOutlineIcon, .toggleSwitchVariantIcon: return .switch2
        case .toggleSwitchOffIcon, .toggleSwitchOffOutlineIcon: return .switch2
        case .toggleSwitchVariantOffIcon, .electricSwitchIcon, .electricSwitchClosedIcon: return .switch2
        case .powerIcon, .powerOnIcon, .powerStandbyIcon, .powerCycleIcon: return .power
        case .powerOffIcon: return .poweroff
        case .powerSleepIcon, .sleepIcon: return .powersleep
        case .powerPlugIcon, .powerPlugOutlineIcon: return .powerplug
        case .powerPlugOffIcon, .powerPlugOffOutlineIcon: return .powerplug
        case .flashIcon, .flashOutlineIcon, .lightningBoltIcon, .lightningBoltOutlineIcon: return .bolt
        case .flashOffIcon: return .boltSlash
        case .transmissionTowerIcon: return .boltFill
        case .batteryChargingWirelessIcon: return .boltBatteryblock
        case .carBatteryIcon: return .minusPlusBatteryblock

        // MARK: Climate & weather (baseline)
        case .weatherSunnyIcon, .whiteBalanceSunnyIcon, .brightness5Icon: return .sunMax
        case .brightness6Icon, .brightness7Icon: return .sunMaxFill
        case .brightness4Icon, .brightnessPercentIcon: return .sunMin
        case .weatherNightIcon: return .moonStars
        case .weatherNightPartlyCloudyIcon: return .cloudMoon
        case .moonWaningCrescentIcon, .moonFullIcon: return .moon
        case .weatherPartlyCloudyIcon: return .cloudSun
        case .weatherCloudyIcon, .cloudIcon, .cloudOutlineIcon: return .cloud
        case .weatherRainyIcon: return .cloudRain
        case .weatherPouringIcon: return .cloudHeavyrain
        case .weatherSnowyIcon, .weatherSnowyHeavyIcon: return .cloudSnow
        case .weatherSnowyRainyIcon: return .cloudSleet
        case .weatherLightningIcon: return .cloudBolt
        case .weatherLightningRainyIcon: return .cloudBoltRain
        case .weatherHailIcon: return .cloudHail
        case .weatherFogIcon: return .cloudFog
        case .weatherWindyIcon, .weatherWindyVariantIcon, .windTurbineIcon: return .wind
        case .weatherHurricaneIcon: return .hurricane
        case .weatherTornadoIcon: return .tornado
        case .weatherHazyIcon: return .sunHaze
        case .weatherSunsetIcon, .weatherSunsetDownIcon: return .sunset
        case .weatherSunsetUpIcon: return .sunrise
        case .sunThermometerIcon, .sunThermometerOutlineIcon: return .thermometerSun
        case .snowflakeThermometerIcon: return .thermometerSnowflake
        case .snowflakeIcon, .snowflakeVariantIcon: return .snowflake
        case .themeLightDarkIcon: return .circleLefthalfFilled
        case .fireIcon, .fireAlertIcon: return .flame
        case .waterPercentIcon, .waterPercentAlertIcon: return .humidity
        case .waterIcon, .waterOutlineIcon, .waterAlertIcon: return .drop
        case .waterOffIcon: return .dropFill
        case .airballoonIcon, .airballoonOutlineIcon: return .airplane

        // MARK: Security & locks
        case .lockIcon, .lockOutlineIcon, .lockSmartIcon: return .lock
        case .lockOpenIcon, .lockOpenOutlineIcon, .lockOpenVariantIcon: return .lockOpen
        case .lockOpenVariantOutlineIcon: return .lockOpen
        case .lockResetIcon: return .lockRotation
        case .keyIcon, .keyOutlineIcon, .keyVariantIcon: return .key
        case .shieldIcon, .shieldOutlineIcon: return .shield
        case .shieldHalfFullIcon, .shieldHomeIcon, .shieldHomeOutlineIcon: return .shieldLefthalfFilled
        case .securityIcon: return .shieldFill
        case .shieldCheckIcon, .shieldCheckOutlineIcon: return .checkmarkShield
        case .shieldAlertIcon, .shieldAlertOutlineIcon: return .exclamationmarkShield
        case .shieldLockIcon, .shieldLockOutlineIcon: return .lockShield
        case .shieldOffIcon, .shieldOffOutlineIcon: return .shieldSlash
        case .doorbellIcon: return .bell
        case .doorbellVideoIcon: return .videoFill
        case .fingerprintIcon: return .touchid
        case .faceRecognitionIcon: return .faceid
        case .eyeIcon, .eyeOutlineIcon: return .eye
        case .eyeOffIcon, .eyeOffOutlineIcon: return .eyeSlash
        case .radarIcon: return .dotRadiowavesLeftAndRight
        case .leakIcon: return .drop

        // MARK: People
        case .accountIcon, .accountOutlineIcon: return .person
        case .accountCircleIcon, .accountCircleOutlineIcon: return .personCircle
        case .accountMultipleIcon, .accountMultipleOutlineIcon: return .person2
        case .accountSupervisorIcon, .accountSupervisorOutlineIcon: return .person2
        case .accountGroupIcon, .accountGroupOutlineIcon: return .person3
        case .googleCirclesCommunitiesIcon: return .person3
        case .accountPlusIcon, .accountPlusOutlineIcon: return .personBadgePlus
        case .accountMinusIcon, .accountMinusOutlineIcon: return .personBadgeMinus
        case .accountRemoveIcon, .accountRemoveOutlineIcon: return .personBadgeMinus
        case .accountCheckIcon, .accountCheckOutlineIcon: return .personCropCircleBadgeCheckmark
        case .accountCancelIcon, .accountCancelOutlineIcon: return .personCropCircleBadgeXmark
        case .accountAlertIcon, .accountAlertOutlineIcon: return .personCropCircleBadgeExclamationmark
        case .accountQuestionIcon, .accountQuestionOutlineIcon: return .personFillQuestionmark
        case .accountVoiceIcon: return .personWave2
        case .badgeAccountIcon, .badgeAccountOutlineIcon: return .personTextRectangle
        case .cardAccountDetailsIcon, .cardAccountDetailsOutlineIcon: return .personTextRectangle
        case .accountTieIcon: return .person
        case .faceManIcon, .faceWomanIcon, .faceManOutlineIcon, .faceWomanOutlineIcon: return .faceSmiling
        case .emoticonIcon, .emoticonOutlineIcon, .emoticonHappyIcon: return .faceSmiling
        case .emoticonHappyOutlineIcon: return .faceSmiling
        case .humanMaleIcon, .humanFemaleIcon, .humanIcon: return .figureStand
        case .humanGreetingIcon, .humanGreetingVariantIcon, .handWaveIcon: return .figureWave
        case .walkIcon: return .figureWalk
        case .gestureTapIcon, .gestureTapButtonIcon, .gestureTapHoldIcon: return .handTap
        case .thumbUpIcon, .thumbUpOutlineIcon: return .handThumbsup
        case .thumbDownIcon, .thumbDownOutlineIcon: return .handThumbsdown

        // MARK: Media players & audio
        case .playIcon, .playOutlineIcon: return .play
        case .playCircleIcon, .playCircleOutlineIcon: return .playCircle
        case .pauseIcon: return .pause
        case .pauseCircleIcon, .pauseCircleOutlineIcon: return .pauseCircle
        case .stopIcon: return .stop
        case .stopCircleIcon, .stopCircleOutlineIcon: return .stopCircle
        case .playPauseIcon: return .playpause
        case .skipNextIcon, .skipNextOutlineIcon, .skipForwardIcon: return .forwardEnd
        case .skipPreviousIcon, .skipPreviousOutlineIcon, .skipBackwardIcon: return .backwardEnd
        case .fastForwardIcon: return .forward
        case .fastForward5Icon: return .goforward5
        case .fastForward10Icon: return .goforward10
        case .fastForward15Icon: return .goforward15
        case .fastForward30Icon: return .goforward30
        case .rewindIcon: return .backward
        case .rewind5Icon: return .gobackward5
        case .rewind10Icon: return .gobackward10
        case .rewind15Icon: return .gobackward15
        case .rewind30Icon: return .gobackward30
        case .shuffleIcon, .shuffleVariantIcon, .shuffleDisabledIcon: return .shuffle
        case .repeatIcon, .repeatOffIcon: return .repeat
        case .repeatOnceIcon: return .repeat1
        case .ejectIcon, .ejectOutlineIcon: return .eject
        case .recordIcon, .recordRecIcon, .recordCircleIcon: return .recordCircle
        case .volumeHighIcon: return .speakerWave3
        case .volumeMediumIcon: return .speakerWave2
        case .volumeLowIcon: return .speakerWave1
        case .volumeOffIcon, .volumeMuteIcon, .volumeVariantOffIcon: return .speakerSlash
        case .speakerIcon: return .hifispeaker
        case .speakerMultipleIcon: return .hifispeaker2
        case .speakerOffIcon: return .speakerSlash
        case .speakerWirelessIcon: return .speakerWave3
        case .speakerMessageIcon: return .textBubble
        case .soundbarIcon: return .hifispeaker
        case .musicIcon, .musicNoteIcon, .musicNoteOutlineIcon: return .musicNote
        case .playlistMusicIcon, .playlistMusicOutlineIcon, .playlistPlayIcon: return .musicNoteList
        case .playlistEditIcon, .playlistPlusIcon: return .musicNoteList
        case .albumIcon, .discIcon, .discPlayerIcon: return .opticaldisc
        case .radioIcon: return .radio
        case .microphoneIcon, .microphoneOutlineIcon, .microphoneVariantIcon: return .mic
        case .microphoneOffIcon, .microphoneVariantOffIcon: return .micSlash
        case .microphoneMessageIcon: return .micCircle
        case .headphonesIcon, .headsetIcon: return .headphones
        case .earbudsIcon, .earbudsOutlineIcon: return .earbuds
        case .earHearingIcon: return .ear
        case .earHearingOffIcon: return .earTrianglebadgeExclamationmark
        case .waveformIcon, .sineWaveIcon, .squareWaveIcon: return .waveform
        case .pulseIcon, .heartPulseIcon: return .waveformPathEcg
        case .televisionIcon, .televisionClassicIcon, .televisionBoxIcon: return .tv
        case .castIcon, .castConnectedIcon, .castVariantIcon: return .airplayvideo
        case .castAudioIcon: return .airplayaudio
        case .castOffIcon: return .airplayvideo
        case .cameraIcon, .cameraOutlineIcon, .cameraFrontIcon: return .camera
        case .cameraSwitchIcon, .cameraSwitchOutlineIcon: return .arrowTriangle2CirclepathCamera
        case .videoIcon, .videoOutlineIcon: return .video
        case .videoOffIcon, .videoOffOutlineIcon: return .videoSlash
        case .filmIcon, .filmstripIcon, .movieIcon, .movieOutlineIcon: return .film
        case .movieOpenIcon, .movieOpenOutlineIcon, .movieRollIcon: return .film
        case .imageIcon, .imageOutlineIcon, .imageAreaIcon: return .photo
        case .imageMultipleIcon, .imageMultipleOutlineIcon: return .photoOnRectangle
        case .cameraImageIcon: return .photo

        // MARK: Communication
        case .emailIcon, .emailOutlineIcon, .emailVariantIcon: return .envelope
        case .emailOpenIcon, .emailOpenOutlineIcon: return .envelopeOpen
        case .sendIcon, .sendOutlineIcon, .emailFastIcon, .emailFastOutlineIcon: return .paperplane
        case .inboxIcon: return .tray
        case .inboxArrowDownIcon: return .trayAndArrowDown
        case .inboxArrowUpIcon: return .trayAndArrowUp
        case .inboxMultipleIcon: return .tray2
        case .messageIcon, .messageOutlineIcon, .messageTextIcon: return .message
        case .messageTextOutlineIcon: return .message
        case .chatIcon, .chatOutlineIcon, .commentIcon, .commentOutlineIcon: return .bubbleLeft
        case .chatProcessingIcon, .chatProcessingOutlineIcon: return .ellipsisBubble
        case .commentTextIcon, .commentTextOutlineIcon: return .textBubble
        case .forumIcon, .forumOutlineIcon: return .bubbleLeftAndBubbleRight
        case .phoneIcon, .phoneOutlineIcon, .phoneClassicIcon, .deskphoneIcon: return .phone
        case .phoneHangupIcon, .phoneOffIcon: return .phoneDown
        case .bullhornIcon, .bullhornOutlineIcon: return .megaphone
        case .bellIcon, .bellOutlineIcon: return .bell
        case .bellOffIcon, .bellOffOutlineIcon, .bellSleepIcon: return .bellSlash
        case .bellRingIcon, .bellRingOutlineIcon, .bellAlertIcon: return .bellBadge
        case .bellPlusIcon, .bellPlusOutlineIcon: return .bellBadge

        // MARK: Devices
        case .cellphoneIcon, .cellphoneBasicIcon: return .iphone
        case .cellphoneOffIcon: return .iphoneSlash
        case .cellphoneWirelessIcon, .cellphoneNfcIcon: return .iphoneRadiowavesLeftAndRight
        case .tabletIcon: return .ipad
        case .laptopIcon, .laptopAccountIcon: return .laptopcomputer
        case .monitorIcon, .desktopTowerMonitorIcon: return .display
        case .desktopClassicIcon: return .desktopcomputer
        case .desktopTowerIcon: return .macproGen3
        case .watchIcon, .watchVariantIcon: return .applewatch
        case .keyboardIcon, .keyboardOutlineIcon, .keyboardVariantIcon: return .keyboard
        case .mouseIcon, .mouseVariantIcon: return .computermouse
        case .printerIcon, .printerOutlineIcon: return .printer
        case .serverIcon, .serverNetworkIcon, .serverSecurityIcon: return .serverRack
        case .nasIcon: return .externaldrive
        case .harddiskIcon: return .internaldrive
        case .usbFlashDriveIcon, .usbFlashDriveOutlineIcon: return .mediastick
        case .usbIcon, .usbPortIcon: return .cableConnector
        case .videoInputHdmiIcon, .cableDataIcon: return .cableConnector
        case .sdIcon: return .sdcard
        case .simIcon, .simOutlineIcon: return .simcard
        case .chipIcon, .cpu64BitIcon, .cpu32BitIcon: return .cpu
        case .memoryIcon, .expansionCardIcon: return .memorychip
        case .databaseIcon, .databaseOutlineIcon: return .cylinderSplit1x2
        case .gamepadIcon, .gamepadVariantIcon, .gamepadVariantOutlineIcon: return .gamecontroller
        case .controllerIcon, .controllerClassicIcon, .controllerClassicOutlineIcon: return .gamecontroller

        // MARK: Connectivity
        case .wifiIcon, .wifiStrength4Icon: return .wifi
        case .wifiStrength1Icon, .wifiStrength2Icon, .wifiStrength3Icon: return .wifi
        case .wifiOffIcon, .wifiStrengthOffIcon, .wifiStrengthOffOutlineIcon: return .wifiSlash
        case .signalVariantIcon, .antennaIcon, .radioTowerIcon: return .antennaRadiowavesLeftAndRight
        case .broadcastIcon: return .dotRadiowavesLeftAndRight
        case .bluetoothIcon, .bluetoothConnectIcon, .bluetoothOffIcon: return .dotRadiowavesRight
        case .nfcIcon, .nfcVariantIcon, .nfcTapIcon: return .wave3Right
        case .networkIcon, .networkOutlineIcon, .lanIcon, .lanConnectIcon: return .network
        case .ethernetIcon, .ethernetCableIcon: return .cableConnector
        case .cloudUploadIcon, .cloudUploadOutlineIcon: return .icloudAndArrowUp
        case .cloudDownloadIcon, .cloudDownloadOutlineIcon: return .icloudAndArrowDown
        case .cloudOffOutlineIcon, .cloudCancelIcon: return .icloudSlash
        case .cloudCheckIcon, .cloudCheckOutlineIcon: return .checkmarkIcloud
        case .cloudAlertIcon: return .exclamationmarkIcloud
        case .cloudLockIcon, .cloudLockOutlineIcon: return .lockIcloud
        case .cloudSyncIcon, .cloudSyncOutlineIcon: return .icloud
        case .qrcodeIcon: return .qrcode
        case .qrcodeScanIcon: return .qrcodeViewfinder
        case .barcodeIcon: return .barcode
        case .barcodeScanIcon: return .barcodeViewfinder

        // MARK: Transport
        case .carIcon, .carSideIcon, .carHatchbackIcon, .carEstateIcon, .taxiIcon: return .car
        case .carSportsIcon, .carConvertibleIcon, .carConnectedIcon, .carWashIcon: return .car
        case .carElectricIcon, .carElectricOutlineIcon: return .boltCar
        case .busIcon, .busSideIcon, .busSchoolIcon, .busDoubleDeckerIcon: return .bus
        case .trainIcon, .trainVariantIcon, .tramIcon, .tramSideIcon: return .tram
        case .subwayIcon, .subwayVariantIcon: return .tramFill
        case .airplaneIcon, .airportIcon: return .airplane
        case .airplaneTakeoffIcon: return .airplaneDeparture
        case .airplaneLandingIcon: return .airplaneArrival
        case .bikeIcon, .bicycleIcon: return .bicycle
        case .scooterIcon, .scooterElectricIcon, .mopedIcon: return .scooter
        case .ferryIcon: return .ferry
        case .fuelIcon, .gasStationIcon: return .fuelpump
        case .mapIcon, .mapOutlineIcon: return .map
        case .mapMarkerIcon, .mapMarkerOutlineIcon: return .mappin
        case .mapMarkerRadiusIcon, .mapMarkerRadiusOutlineIcon: return .mappinAndEllipse
        case .mapMarkerMultipleIcon, .mapMarkerMultipleOutlineIcon: return .mappinAndEllipse
        case .mapMarkerOffIcon: return .mappinSlash
        case .crosshairsIcon, .crosshairsGpsIcon: return .scope
        case .navigationIcon, .navigationOutlineIcon, .navigationVariantIcon: return .locationNorthFill
        case .nearMeIcon: return .locationFill
        case .earthIcon, .webIcon, .globeModelIcon: return .globe
        case .signDirectionIcon: return .signpostRight
        case .directionsIcon: return .arrowTriangleTurnUpRightDiamond
        case .routesIcon, .callSplitIcon, .sourceBranchIcon: return .arrowTriangleBranch

        // MARK: Time & calendar
        case .clockIcon, .clockOutlineIcon, .clockDigitalIcon, .clockFastIcon: return .clock
        case .alarmIcon: return .alarm
        case .timerIcon, .timerOutlineIcon, .timerOffIcon, .timerOffOutlineIcon: return .timer
        case .timerSandIcon, .timerSandEmptyIcon, .timerSandCompleteIcon: return .hourglass
        case .historyIcon: return .clockArrowCirclepath
        case .updateIcon: return .clockArrowCirclepath
        case .calendarIcon, .calendarBlankIcon, .calendarOutlineIcon: return .calendar
        case .calendarBlankOutlineIcon, .calendarMonthIcon, .calendarMonthOutlineIcon: return .calendar
        case .calendarTodayIcon, .calendarStarIcon, .calendarRangeIcon: return .calendar
        case .calendarWeekIcon, .calendarTextIcon, .calendarMultipleIcon: return .calendar
        case .calendarClockIcon, .calendarClockOutlineIcon: return .calendarBadgeClock
        case .calendarPlusIcon: return .calendarBadgePlus
        case .calendarMinusIcon, .calendarRemoveIcon, .calendarRemoveOutlineIcon: return .calendarBadgeMinus
        case .calendarAlertIcon: return .calendarBadgeExclamationmark

        // MARK: Files & documents
        case .fileIcon, .fileOutlineIcon: return .doc
        case .fileDocumentIcon, .fileDocumentOutlineIcon: return .docText
        case .fileMultipleIcon, .fileMultipleOutlineIcon: return .docOnDoc
        case .filePlusIcon, .filePlusOutlineIcon: return .docBadgePlus
        case .fileSearchIcon, .fileSearchOutlineIcon: return .docTextMagnifyingglass
        case .fileChartIcon, .fileChartOutlineIcon: return .chartBarDocHorizontal
        case .fileCabinetIcon, .archiveIcon, .archiveOutlineIcon: return .archivebox
        case .folderIcon, .folderOutlineIcon, .folderOpenIcon, .folderOpenOutlineIcon: return .folder
        case .folderMultipleIcon, .folderMultipleOutlineIcon, .folderHomeIcon: return .folder
        case .folderPlusIcon, .folderPlusOutlineIcon: return .folderBadgePlus
        case .folderMinusIcon, .folderMinusOutlineIcon: return .folderBadgeMinus
        case .folderAccountIcon, .folderAccountOutlineIcon: return .folderBadgePersonCrop
        case .packageIcon, .packageVariantIcon, .packageVariantClosedIcon: return .shippingbox
        case .packageUpIcon, .packageDownIcon: return .shippingbox
        case .contentCopyIcon: return .docOnDoc
        case .contentPasteIcon: return .docOnClipboard
        case .contentCutIcon, .scissorsCuttingIcon: return .scissors
        case .contentSaveIcon, .contentSaveOutlineIcon: return .squareAndArrowDown
        case .clipboardCheckIcon, .clipboardCheckOutlineIcon: return .checklist
        case .noteIcon, .noteOutlineIcon, .noteMultipleIcon: return .note
        case .noteTextIcon, .noteTextOutlineIcon: return .noteText
        case .notebookIcon, .notebookOutlineIcon: return .bookClosed
        case .bookIcon, .bookOutlineIcon: return .bookClosed
        case .bookOpenIcon, .bookOpenOutlineIcon, .bookOpenVariantIcon: return .book
        case .bookOpenPageVariantIcon, .bookOpenPageVariantOutlineIcon: return .book
        case .bookMultipleIcon, .bookshelfIcon, .libraryIcon, .libraryOutlineIcon: return .booksVertical
        case .newspaperIcon, .newspaperVariantIcon, .newspaperVariantOutlineIcon: return .newspaper
        case .scriptTextIcon, .scriptTextOutlineIcon, .scriptIcon, .scriptOutlineIcon: return .scroll
        case .textBoxIcon, .textBoxOutlineIcon: return .docPlaintext
        case .formTextboxIcon: return .characterCursorIbeam
        case .textIcon, .textLongIcon, .textShortIcon: return .textAlignleft
        case .formatListBulletedIcon, .formatListBulletedTriangleIcon: return .listBullet
        case .formatListNumberedIcon: return .listNumber
        case .formatListChecksIcon, .formatListCheckboxIcon: return .checklist
        case .receiptIcon, .receiptTextIcon, .receiptTextOutlineIcon: return .docPlaintext

        // MARK: Editing & actions
        case .pencilIcon, .pencilOutlineIcon, .leadPencilIcon: return .pencil
        case .pencilOffIcon: return .pencilSlash
        case .drawIcon: return .pencilAndOutline
        case .penIcon: return .pencilTip
        case .deleteIcon, .deleteOutlineIcon, .deleteEmptyIcon: return .trash
        case .trashCanIcon, .trashCanOutlineIcon, .deleteForeverIcon: return .trash
        case .magnifyIcon: return .magnifyingglass
        case .magnifyPlusIcon, .magnifyPlusOutlineIcon: return .plusMagnifyingglass
        case .magnifyMinusIcon, .magnifyMinusOutlineIcon: return .minusMagnifyingglass
        case .filterVariantIcon: return .line3HorizontalDecrease
        case .filterIcon, .filterOutlineIcon: return .line3HorizontalDecreaseCircle
        case .refreshIcon, .reloadIcon, .autorenewIcon, .cachedIcon: return .arrowClockwise
        case .restartIcon: return .arrowClockwiseCircle
        case .restoreIcon: return .arrowCounterclockwise
        case .syncIcon, .syncCircleIcon: return .arrowTriangle2Circlepath
        case .rotateLeftIcon: return .rotateLeft
        case .rotateRightIcon: return .rotateRight
        case .rotate3dVariantIcon: return .rotate3d
        case .undoIcon, .undoVariantIcon: return .arrowUturnBackward
        case .redoIcon, .redoVariantIcon: return .arrowUturnForward
        case .uploadIcon, .uploadOutlineIcon: return .squareAndArrowUp
        case .downloadIcon, .downloadOutlineIcon: return .squareAndArrowDown
        case .shareIcon, .shareVariantIcon, .shareVariantOutlineIcon: return .squareAndArrowUp
        case .exportVariantIcon: return .squareAndArrowUp
        case .openInNewIcon, .launchIcon: return .arrowUpRightSquare
        case .openInAppIcon: return .arrowUpForwardApp
        case .loginIcon, .loginVariantIcon: return .arrowRightSquare
        case .logoutIcon, .logoutVariantIcon, .exitToAppIcon: return .rectanglePortraitAndArrowRight
        case .fullscreenIcon, .arrowExpandIcon, .arrowExpandAllIcon: return .arrowUpLeftAndArrowDownRight
        case .fullscreenExitIcon, .arrowCollapseIcon, .arrowCollapseAllIcon: return .arrowDownRightAndArrowUpLeft
        case .linkIcon, .linkVariantIcon: return .link
        case .paperclipIcon: return .paperclip
        case .pinIcon, .pinOutlineIcon: return .pin
        case .pinOffIcon, .pinOffOutlineIcon: return .pinSlash

        // MARK: Basic UI
        case .closeIcon, .closeThickIcon, .windowCloseIcon: return .xmark
        case .closeCircleIcon, .closeCircleOutlineIcon: return .xmarkCircle
        case .closeBoxIcon, .closeBoxOutlineIcon: return .xmarkSquare
        case .checkIcon, .checkBoldIcon, .checkAllIcon: return .checkmark
        case .checkCircleIcon, .checkCircleOutlineIcon: return .checkmarkCircle
        case .checkboxMarkedIcon, .checkboxMarkedOutlineIcon: return .checkmarkSquare
        case .checkboxMarkedCircleIcon, .checkboxMarkedCircleOutlineIcon: return .checkmarkCircleFill
        case .checkboxBlankOutlineIcon: return .square
        case .checkboxBlankCircleOutlineIcon: return .circle
        case .checkboxBlankCircleIcon: return .circleFill
        case .checkDecagramIcon, .checkDecagramOutlineIcon: return .checkmarkSeal
        case .plusIcon, .plusThickIcon: return .plus
        case .plusCircleIcon, .plusCircleOutlineIcon: return .plusCircle
        case .plusBoxIcon, .plusBoxOutlineIcon: return .plusSquare
        case .minusIcon, .minusThickIcon: return .minus
        case .minusCircleIcon, .minusCircleOutlineIcon: return .minusCircle
        case .minusBoxIcon, .minusBoxOutlineIcon: return .minusSquare
        case .menuIcon: return .line3Horizontal
        case .dotsHorizontalIcon, .dotsVerticalIcon: return .ellipsis
        case .menuDownIcon, .chevronDownIcon: return .chevronDown
        case .menuUpIcon, .chevronUpIcon: return .chevronUp
        case .menuLeftIcon, .chevronLeftIcon: return .chevronLeft
        case .menuRightIcon, .chevronRightIcon: return .chevronRight
        case .arrowUpIcon, .arrowUpThickIcon, .arrowUpBoldIcon: return .arrowUp
        case .arrowDownIcon, .arrowDownThickIcon, .arrowDownBoldIcon: return .arrowDown
        case .arrowLeftIcon, .arrowLeftThickIcon, .arrowLeftBoldIcon: return .arrowLeft
        case .arrowRightIcon, .arrowRightThickIcon, .arrowRightBoldIcon: return .arrowRight
        case .arrowTopRightIcon: return .arrowUpRight
        case .arrowTopLeftIcon: return .arrowUpLeft
        case .arrowBottomRightIcon: return .arrowDownRight
        case .arrowBottomLeftIcon: return .arrowDownLeft
        case .arrowLeftRightIcon: return .arrowLeftAndRight
        case .arrowUpDownIcon: return .arrowUpAndDown
        case .swapHorizontalIcon, .swapHorizontalVariantIcon: return .arrowLeftArrowRight
        case .swapVerticalIcon, .swapVerticalVariantIcon: return .arrowUpArrowDown
        case .subdirectoryArrowLeftIcon: return .arrowTurnDownLeft
        case .alertIcon, .alertOutlineIcon: return .exclamationmarkTriangle
        case .alertCircleIcon, .alertCircleOutlineIcon: return .exclamationmarkCircle
        case .alertOctagonIcon, .alertOctagonOutlineIcon: return .exclamationmarkOctagon
        case .informationIcon, .informationOutlineIcon: return .infoCircle
        case .informationVariantIcon: return .info
        case .helpIcon: return .questionmark
        case .helpCircleIcon, .helpCircleOutlineIcon: return .questionmarkCircle
        case .cancelIcon, .blockHelperIcon: return .nosign
        case .starIcon, .starOutlineIcon: return .star
        case .starCircleIcon, .starCircleOutlineIcon: return .starCircle
        case .starOffIcon, .starOffOutlineIcon: return .starSlash
        case .starHalfFullIcon: return .starLeadinghalfFilled
        case .heartIcon, .heartOutlineIcon: return .heart
        case .heartOffIcon, .heartOffOutlineIcon: return .heartSlash
        case .flagIcon, .flagOutlineIcon, .flagVariantIcon, .flagVariantOutlineIcon: return .flag
        case .bookmarkIcon, .bookmarkOutlineIcon: return .bookmark
        case .tagIcon, .tagOutlineIcon, .tagMultipleIcon, .tagMultipleOutlineIcon: return .tag
        case .labelIcon, .labelOutlineIcon, .labelVariantIcon, .labelVariantOutlineIcon: return .tag
        case .eyedropperIcon, .eyedropperVariantIcon: return .eyedropper
        case .paletteIcon, .paletteOutlineIcon: return .paintpalette
        case .brushIcon, .brushOutlineIcon, .brushVariantIcon: return .paintbrush
        case .formatPaintIcon: return .paintbrushPointed
        case .gestureSwipeIcon: return .handDraw

        // MARK: Settings & tools
        case .cogIcon, .cogOutlineIcon: return .gearshape
        case .cogsIcon: return .gearshape2
        case .tuneIcon, .tuneVariantIcon: return .sliderHorizontal3
        case .tuneVerticalIcon, .tuneVerticalVariantIcon, .equalizerIcon: return .sliderVertical3
        case .wrenchClockIcon: return .wrenchAndScrewdriver
        case .toolsIcon, .toolboxIcon, .toolboxOutlineIcon: return .wrenchAndScrewdriver
        case .hammerWrenchIcon: return .wrenchAndScrewdriver
        case .hammerIcon: return .hammer
        case .screwdriverIcon: return .screwdriver
        case .rulerIcon, .rulerSquareIcon, .tapeMeasureIcon: return .ruler
        case .bugIcon, .bugOutlineIcon: return .ant
        case .ladybugIcon: return .ladybug
        case .autoFixIcon, .magicStaffIcon: return .wandAndStars
        case .shimmerIcon, .creationIcon: return .sparkles
        case .scaleIcon, .scaleBathroomIcon, .weightIcon: return .scalemass
        case .weightKilogramIcon, .weightPoundIcon: return .scalemass
        case .umbrellaIcon, .umbrellaOutlineIcon, .umbrellaClosedIcon: return .umbrella
        case .glassesIcon: return .eyeglasses
        case .tshirtCrewIcon, .tshirtCrewOutlineIcon, .tshirtVIcon: return .tshirt
        case .bagSuitcaseIcon, .bagSuitcaseOutlineIcon: return .suitcase
        case .briefcaseIcon, .briefcaseOutlineIcon, .briefcaseVariantIcon: return .briefcase
        case .binocularsIcon: return .binoculars
        case .giftIcon, .giftOutlineIcon: return .gift
        case .crownIcon, .crownOutlineIcon: return .crown
        case .puzzleIcon, .puzzleOutlineIcon: return .puzzlepiece
        case .diceMultipleIcon, .dice5Icon: return .dieFace5
        case .dice1Icon: return .dieFace1
        case .dice2Icon: return .dieFace2
        case .dice3Icon: return .dieFace3
        case .dice4Icon: return .dieFace4
        case .dice6Icon: return .dieFace6
        case .pianoIcon: return .pianokeys
        case .guitarAcousticIcon, .guitarElectricIcon: return .guitars
        case .recycleIcon, .recycleVariantIcon: return .arrow3Trianglepath
        case .infinityIcon, .allInclusiveIcon: return .infinity
        case .keyChainIcon, .keyChainVariantIcon: return .key

        // MARK: Health
        case .medicalBagIcon: return .crossCase
        case .hospitalIcon, .hospitalBoxIcon, .hospitalBoxOutlineIcon: return .cross
        case .ambulanceIcon: return .cross
        case .pillIcon: return .pills
        case .bandageIcon: return .bandage
        case .stethoscopeIcon: return .stethoscope
        case .lungsIcon: return .lungs
        case .brainIcon: return .brain
        case .testTubeIcon: return .testtube2
        case .atomIcon, .atomVariantIcon: return .atom

        // MARK: Food & dining
        case .silverwareIcon, .silverwareForkKnifeIcon, .silverwareVariantIcon: return .forkKnife
        case .foodIcon, .foodVariantIcon: return .forkKnife
        case .coffeeIcon, .coffeeOutlineIcon, .coffeeMakerIcon: return .cupAndSaucer
        case .coffeeMakerOutlineIcon, .cupIcon, .cupOutlineIcon: return .cupAndSaucer

        // MARK: Nature & animals (baseline)
        case .leafIcon, .leafCircleIcon, .leafCircleOutlineIcon, .sproutIcon: return .leaf
        case .sproutOutlineIcon, .grassIcon: return .leaf
        case .pawIcon, .pawOutlineIcon: return .pawprint
        case .rabbitIcon, .rabbitVariantIcon, .rabbitVariantOutlineIcon: return .hare
        case .turtleIcon, .tortoiseIcon: return .tortoise
        case .fireExtinguisherIcon: return .flame

        // MARK: Beds & bedroom
        case .bedIcon, .bedOutlineIcon, .bedDoubleIcon, .bedDoubleOutlineIcon: return .bedDouble
        case .bedKingIcon, .bedKingOutlineIcon, .bedQueenIcon, .bedQueenOutlineIcon: return .bedDouble
        case .bedSingleIcon, .bedSingleOutlineIcon, .bedEmptyIcon: return .bedDouble

        // MARK: Commerce & data
        case .creditCardIcon, .creditCardOutlineIcon: return .creditcard
        case .creditCardWirelessIcon, .creditCardWirelessOutlineIcon: return .creditcard
        case .cashIcon, .cashMultipleIcon: return .banknote
        case .currencyUsdIcon: return .dollarsignCircle
        case .currencyEurIcon: return .eurosignCircle
        case .currencyGbpIcon: return .sterlingsignCircle
        case .currencyBtcIcon: return .bitcoinsignCircle
        case .currencyJpyIcon: return .yensignCircle
        case .cartIcon, .cartOutlineIcon, .cartVariantIcon: return .cart
        case .cartPlusIcon: return .cartBadgePlus
        case .cartMinusIcon: return .cartBadgeMinus
        case .basketIcon, .basketOutlineIcon: return .cart
        case .shoppingIcon, .shoppingOutlineIcon: return .bag
        case .walletIcon, .walletOutlineIcon: return .walletPass
        case .bankIcon, .bankOutlineIcon: return .buildingColumns
        case .ticketIcon, .ticketOutlineIcon, .ticketConfirmationIcon: return .ticket
        case .chartLineIcon, .chartLineVariantIcon, .chartAreasplineIcon: return .chartXyaxisLine
        case .chartTimelineVariantIcon: return .chartXyaxisLine
        case .chartBarIcon, .chartBarStackedIcon, .pollIcon, .financeIcon: return .chartBar
        case .chartPieIcon, .chartDonutIcon, .chartDonutVariantIcon: return .chartPie
        case .chartBellCurveIcon, .chartBellCurveCumulativeIcon: return .chartXyaxisLine
        case .trendingUpIcon: return .chartLineUptrendXyaxis
        case .sitemapIcon, .sitemapOutlineIcon: return .rectangle3Group

        // MARK: Code & math
        case .codeBracesIcon, .codeJsonIcon: return .curlybraces
        case .codeTagsIcon, .xmlIcon: return .chevronLeftForwardslashChevronRight
        case .functionIcon, .functionVariantIcon: return .function
        case .sigmaIcon: return .sum
        case .percentIcon, .percentOutlineIcon: return .percent
        case .equalIcon: return .equal
        case .plusMinusIcon, .plusMinusVariantIcon: return .plusminus
        case .divisionIcon: return .divide
        case .multiplicationIcon: return .multiply
        case .numericIcon, .poundIcon, .counterIcon: return .number
        case .translateIcon: return .characterBookClosed

        // MARK: Older-OS fallbacks for newer matches
        case .storeIcon, .storeOutlineIcon, .storefrontOutlineIcon: return .building
        case .evStationIcon: return .boltCar
        case .dogIcon, .dogSideIcon, .dogServiceIcon, .catIcon: return .pawprint
        case .accountOffIcon, .accountOffOutlineIcon: return .personCropCircleBadgeXmark
        case .flaskIcon, .flaskOutlineIcon, .flaskEmptyIcon, .flaskEmptyOutlineIcon: return .testtube2
        case .sunglassesIcon: return .eyeglasses
        case .calendarCheckIcon, .calendarCheckOutlineIcon: return .calendar
        case .televisionOffIcon, .televisionClassicOffIcon: return .tv
        case .batteryChargingIcon, .batteryChargingHighIcon, .batteryCharging100Icon: return .boltBatteryblock

        default: return nil
        }
    }
}

