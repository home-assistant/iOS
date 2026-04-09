// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum CoreStrings {
  /// Active
  public static var commonStateActive: String { return CoreStrings.tr("Core", "common::state::active", fallback: "Active") }
  /// Closed
  public static var commonStateClosed: String { return CoreStrings.tr("Core", "common::state::closed", fallback: "Closed") }
  /// Connected
  public static var commonStateConnected: String { return CoreStrings.tr("Core", "common::state::connected", fallback: "Connected") }
  /// Disabled
  public static var commonStateDisabled: String { return CoreStrings.tr("Core", "common::state::disabled", fallback: "Disabled") }
  /// Disconnected
  public static var commonStateDisconnected: String { return CoreStrings.tr("Core", "common::state::disconnected", fallback: "Disconnected") }
  /// Enabled
  public static var commonStateEnabled: String { return CoreStrings.tr("Core", "common::state::enabled", fallback: "Enabled") }
  /// Home
  public static var commonStateHome: String { return CoreStrings.tr("Core", "common::state::home", fallback: "Home") }
  /// Idle
  public static var commonStateIdle: String { return CoreStrings.tr("Core", "common::state::idle", fallback: "Idle") }
  /// Locked
  public static var commonStateLocked: String { return CoreStrings.tr("Core", "common::state::locked", fallback: "Locked") }
  /// No
  public static var commonStateNo: String { return CoreStrings.tr("Core", "common::state::no", fallback: "No") }
  /// Away
  public static var commonStateNotHome: String { return CoreStrings.tr("Core", "common::state::not_home", fallback: "Away") }
  /// Off
  public static var commonStateOff: String { return CoreStrings.tr("Core", "common::state::off", fallback: "Off") }
  /// On
  public static var commonStateOn: String { return CoreStrings.tr("Core", "common::state::on", fallback: "On") }
  /// Open
  public static var commonStateOpen: String { return CoreStrings.tr("Core", "common::state::open", fallback: "Open") }
  /// Paused
  public static var commonStatePaused: String { return CoreStrings.tr("Core", "common::state::paused", fallback: "Paused") }
  /// Standby
  public static var commonStateStandby: String { return CoreStrings.tr("Core", "common::state::standby", fallback: "Standby") }
  /// Unlocked
  public static var commonStateUnlocked: String { return CoreStrings.tr("Core", "common::state::unlocked", fallback: "Unlocked") }
  /// Yes
  public static var commonStateYes: String { return CoreStrings.tr("Core", "common::state::yes", fallback: "Yes") }
  /// Off
  public static var componentAirzoneEntitySelectSleepTimesStateOff: String { return CoreStrings.tr("Core", "component::airzone::entity::select::sleep_times::state::off", fallback: "Off") }
  /// Idle
  public static var componentAlertEntityComponentStateIdle: String { return CoreStrings.tr("Core", "component::alert::entity_component::_::state::idle", fallback: "Idle") }
  /// Active
  public static var componentAlertEntityComponentStateOn: String { return CoreStrings.tr("Core", "component::alert::entity_component::_::state::on", fallback: "Active") }
  /// Off
  public static var componentAutomationEntityComponentStateOff: String { return CoreStrings.tr("Core", "component::automation::entity_component::_::state::off", fallback: "Off") }
  /// On
  public static var componentAutomationEntityComponentStateOn: String { return CoreStrings.tr("Core", "component::automation::entity_component::_::state::on", fallback: "On") }
  /// Off
  public static var componentBinarySensorEntityComponentStateOff: String { return CoreStrings.tr("Core", "component::binary_sensor::entity_component::_::state::off", fallback: "Off") }
  /// On
  public static var componentBinarySensorEntityComponentStateOn: String { return CoreStrings.tr("Core", "component::binary_sensor::entity_component::_::state::on", fallback: "On") }
  /// Disconnected
  public static var componentBinarySensorEntityComponentConnectivityStateOff: String { return CoreStrings.tr("Core", "component::binary_sensor::entity_component::connectivity::state::off", fallback: "Disconnected") }
  /// Connected
  public static var componentBinarySensorEntityComponentConnectivityStateOn: String { return CoreStrings.tr("Core", "component::binary_sensor::entity_component::connectivity::state::on", fallback: "Connected") }
  /// Closed
  public static var componentBinarySensorEntityComponentDoorStateOff: String { return CoreStrings.tr("Core", "component::binary_sensor::entity_component::door::state::off", fallback: "Closed") }
  /// Open
  public static var componentBinarySensorEntityComponentDoorStateOn: String { return CoreStrings.tr("Core", "component::binary_sensor::entity_component::door::state::on", fallback: "Open") }
  /// Closed
  public static var componentBinarySensorEntityComponentGarageDoorStateOff: String { return CoreStrings.tr("Core", "component::binary_sensor::entity_component::garage_door::state::off", fallback: "Closed") }
  /// Open
  public static var componentBinarySensorEntityComponentGarageDoorStateOn: String { return CoreStrings.tr("Core", "component::binary_sensor::entity_component::garage_door::state::on", fallback: "Open") }
  /// Locked
  public static var componentBinarySensorEntityComponentLockStateOff: String { return CoreStrings.tr("Core", "component::binary_sensor::entity_component::lock::state::off", fallback: "Locked") }
  /// Unlocked
  public static var componentBinarySensorEntityComponentLockStateOn: String { return CoreStrings.tr("Core", "component::binary_sensor::entity_component::lock::state::on", fallback: "Unlocked") }
  /// Closed
  public static var componentBinarySensorEntityComponentOpeningStateOff: String { return CoreStrings.tr("Core", "component::binary_sensor::entity_component::opening::state::off", fallback: "Closed") }
  /// Open
  public static var componentBinarySensorEntityComponentOpeningStateOn: String { return CoreStrings.tr("Core", "component::binary_sensor::entity_component::opening::state::on", fallback: "Open") }
  /// Away
  public static var componentBinarySensorEntityComponentPresenceStateOff: String { return CoreStrings.tr("Core", "component::binary_sensor::entity_component::presence::state::off", fallback: "Away") }
  /// Home
  public static var componentBinarySensorEntityComponentPresenceStateOn: String { return CoreStrings.tr("Core", "component::binary_sensor::entity_component::presence::state::on", fallback: "Home") }
  /// Closed
  public static var componentBinarySensorEntityComponentWindowStateOff: String { return CoreStrings.tr("Core", "component::binary_sensor::entity_component::window::state::off", fallback: "Closed") }
  /// Open
  public static var componentBinarySensorEntityComponentWindowStateOn: String { return CoreStrings.tr("Core", "component::binary_sensor::entity_component::window::state::on", fallback: "Open") }
  /// Button
  public static var componentButtonTitle: String { return CoreStrings.tr("Core", "component::button::title", fallback: "Button") }
  /// Off
  public static var componentCalendarEntityComponentStateOff: String { return CoreStrings.tr("Core", "component::calendar::entity_component::_::state::off", fallback: "Off") }
  /// On
  public static var componentCalendarEntityComponentStateOn: String { return CoreStrings.tr("Core", "component::calendar::entity_component::_::state::on", fallback: "On") }
  /// No
  public static var componentCalendarEntityComponentStateAttributesAllDayStateFalse: String { return CoreStrings.tr("Core", "component::calendar::entity_component::_::state_attributes::all_day::state::false", fallback: "No") }
  /// Yes
  public static var componentCalendarEntityComponentStateAttributesAllDayStateTrue: String { return CoreStrings.tr("Core", "component::calendar::entity_component::_::state_attributes::all_day::state::true", fallback: "Yes") }
  /// Idle
  public static var componentCameraEntityComponentStateIdle: String { return CoreStrings.tr("Core", "component::camera::entity_component::_::state::idle", fallback: "Idle") }
  /// Disabled
  public static var componentCameraEntityComponentStateAttributesMotionDetectionStateFalse: String { return CoreStrings.tr("Core", "component::camera::entity_component::_::state_attributes::motion_detection::state::false", fallback: "Disabled") }
  /// Enabled
  public static var componentCameraEntityComponentStateAttributesMotionDetectionStateTrue: String { return CoreStrings.tr("Core", "component::camera::entity_component::_::state_attributes::motion_detection::state::true", fallback: "Enabled") }
  /// Off
  public static var componentClimateEntityComponentStateOff: String { return CoreStrings.tr("Core", "component::climate::entity_component::_::state::off", fallback: "Off") }
  /// Off
  public static var componentClimateEntityComponentStateAttributesFanModeStateOff: String { return CoreStrings.tr("Core", "component::climate::entity_component::_::state_attributes::fan_mode::state::off", fallback: "Off") }
  /// On
  public static var componentClimateEntityComponentStateAttributesFanModeStateOn: String { return CoreStrings.tr("Core", "component::climate::entity_component::_::state_attributes::fan_mode::state::on", fallback: "On") }
  /// Idle
  public static var componentClimateEntityComponentStateAttributesHvacActionStateIdle: String { return CoreStrings.tr("Core", "component::climate::entity_component::_::state_attributes::hvac_action::state::idle", fallback: "Idle") }
  /// Off
  public static var componentClimateEntityComponentStateAttributesHvacActionStateOff: String { return CoreStrings.tr("Core", "component::climate::entity_component::_::state_attributes::hvac_action::state::off", fallback: "Off") }
  /// Home
  public static var componentClimateEntityComponentStateAttributesPresetModeStateHome: String { return CoreStrings.tr("Core", "component::climate::entity_component::_::state_attributes::preset_mode::state::home", fallback: "Home") }
  /// Off
  public static var componentClimateEntityComponentStateAttributesSwingModeStateOff: String { return CoreStrings.tr("Core", "component::climate::entity_component::_::state_attributes::swing_mode::state::off", fallback: "Off") }
  /// On
  public static var componentClimateEntityComponentStateAttributesSwingModeStateOn: String { return CoreStrings.tr("Core", "component::climate::entity_component::_::state_attributes::swing_mode::state::on", fallback: "On") }
  /// No
  public static var componentCounterEntityComponentStateAttributesEditableStateFalse: String { return CoreStrings.tr("Core", "component::counter::entity_component::_::state_attributes::editable::state::false", fallback: "No") }
  /// Yes
  public static var componentCounterEntityComponentStateAttributesEditableStateTrue: String { return CoreStrings.tr("Core", "component::counter::entity_component::_::state_attributes::editable::state::true", fallback: "Yes") }
  /// Closed
  public static var componentCoverEntityComponentStateClosed: String { return CoreStrings.tr("Core", "component::cover::entity_component::_::state::closed", fallback: "Closed") }
  /// Open
  public static var componentCoverEntityComponentStateOpen: String { return CoreStrings.tr("Core", "component::cover::entity_component::_::state::open", fallback: "Open") }
  /// Cover
  public static var componentCoverTitle: String { return CoreStrings.tr("Core", "component::cover::title", fallback: "Cover") }
  /// Idle
  public static var componentDelugeEntitySensorStatusStateIdle: String { return CoreStrings.tr("Core", "component::deluge::entity::sensor::status::state::idle", fallback: "Idle") }
  /// Off
  public static var componentDemoEntityClimateUbercoolStateAttributesSwingModeStateOff: String { return CoreStrings.tr("Core", "component::demo::entity::climate::ubercool::state_attributes::swing_mode::state::off", fallback: "Off") }
  /// Away
  public static var componentDemoEntitySensorThermostatModeStateAway: String { return CoreStrings.tr("Core", "component::demo::entity::sensor::thermostat_mode::state::away", fallback: "Away") }
  /// Home
  public static var componentDeviceTrackerEntityComponentStateHome: String { return CoreStrings.tr("Core", "component::device_tracker::entity_component::_::state::home", fallback: "Home") }
  /// Away
  public static var componentDeviceTrackerEntityComponentStateNotHome: String { return CoreStrings.tr("Core", "component::device_tracker::entity_component::_::state::not_home", fallback: "Away") }
  /// Off
  public static var componentEcoforestEntitySensorStatusStateOff: String { return CoreStrings.tr("Core", "component::ecoforest::entity::sensor::status::state::off", fallback: "Off") }
  /// On
  public static var componentEcoforestEntitySensorStatusStateOn: String { return CoreStrings.tr("Core", "component::ecoforest::entity::sensor::status::state::on", fallback: "On") }
  /// Standby
  public static var componentEcoforestEntitySensorStatusStateStandBy: String { return CoreStrings.tr("Core", "component::ecoforest::entity::sensor::status::state::stand_by", fallback: "Standby") }
  /// Off
  public static var componentFanEntityComponentStateOff: String { return CoreStrings.tr("Core", "component::fan::entity_component::_::state::off", fallback: "Off") }
  /// On
  public static var componentFanEntityComponentStateOn: String { return CoreStrings.tr("Core", "component::fan::entity_component::_::state::on", fallback: "On") }
  /// No
  public static var componentFanEntityComponentStateAttributesOscillatingStateFalse: String { return CoreStrings.tr("Core", "component::fan::entity_component::_::state_attributes::oscillating::state::false", fallback: "No") }
  /// Yes
  public static var componentFanEntityComponentStateAttributesOscillatingStateTrue: String { return CoreStrings.tr("Core", "component::fan::entity_component::_::state_attributes::oscillating::state::true", fallback: "Yes") }
  /// Idle
  public static var componentFritzboxCallmonitorEntitySensorFritzboxCallmonitorStateIdle: String { return CoreStrings.tr("Core", "component::fritzbox_callmonitor::entity::sensor::fritzbox_callmonitor::state::idle", fallback: "Idle") }
  /// Open
  public static var componentGardenaBluetoothEntitySwitchStateName: String { return CoreStrings.tr("Core", "component::gardena_bluetooth::entity::switch::state::name", fallback: "Open") }
  /// Enabled
  public static var componentGoogleMailServicesSetVacationFieldsEnabledName: String { return CoreStrings.tr("Core", "component::google_mail::services::set_vacation::fields::enabled::name", fallback: "Enabled") }
  /// Closed
  public static var componentGroupEntityComponentStateClosed: String { return CoreStrings.tr("Core", "component::group::entity_component::_::state::closed", fallback: "Closed") }
  /// Home
  public static var componentGroupEntityComponentStateHome: String { return CoreStrings.tr("Core", "component::group::entity_component::_::state::home", fallback: "Home") }
  /// Locked
  public static var componentGroupEntityComponentStateLocked: String { return CoreStrings.tr("Core", "component::group::entity_component::_::state::locked", fallback: "Locked") }
  /// Away
  public static var componentGroupEntityComponentStateNotHome: String { return CoreStrings.tr("Core", "component::group::entity_component::_::state::not_home", fallback: "Away") }
  /// Off
  public static var componentGroupEntityComponentStateOff: String { return CoreStrings.tr("Core", "component::group::entity_component::_::state::off", fallback: "Off") }
  /// On
  public static var componentGroupEntityComponentStateOn: String { return CoreStrings.tr("Core", "component::group::entity_component::_::state::on", fallback: "On") }
  /// Open
  public static var componentGroupEntityComponentStateOpen: String { return CoreStrings.tr("Core", "component::group::entity_component::_::state::open", fallback: "Open") }
  /// Unlocked
  public static var componentGroupEntityComponentStateUnlocked: String { return CoreStrings.tr("Core", "component::group::entity_component::_::state::unlocked", fallback: "Unlocked") }
  /// Standby
  public static var componentHdmiCecServicesStandbyName: String { return CoreStrings.tr("Core", "component::hdmi_cec::services::standby::name", fallback: "Standby") }
  /// Away
  public static var componentHomekitControllerEntitySelectEcobeeModeStateAway: String { return CoreStrings.tr("Core", "component::homekit_controller::entity::select::ecobee_mode::state::away", fallback: "Away") }
  /// Home
  public static var componentHomekitControllerEntitySelectEcobeeModeStateHome: String { return CoreStrings.tr("Core", "component::homekit_controller::entity::select::ecobee_mode::state::home", fallback: "Home") }
  /// Disabled
  public static var componentHomekitControllerEntitySensorThreadStatusStateDisabled: String { return CoreStrings.tr("Core", "component::homekit_controller::entity::sensor::thread_status::state::disabled", fallback: "Disabled") }
  /// Connected
  public static var componentHueEntitySensorZigbeeConnectivityStateConnected: String { return CoreStrings.tr("Core", "component::hue::entity::sensor::zigbee_connectivity::state::connected", fallback: "Connected") }
  /// Disconnected
  public static var componentHueEntitySensorZigbeeConnectivityStateDisconnected: String { return CoreStrings.tr("Core", "component::hue::entity::sensor::zigbee_connectivity::state::disconnected", fallback: "Disconnected") }
  /// Off
  public static var componentHumidifierEntityComponentStateOff: String { return CoreStrings.tr("Core", "component::humidifier::entity_component::_::state::off", fallback: "Off") }
  /// On
  public static var componentHumidifierEntityComponentStateOn: String { return CoreStrings.tr("Core", "component::humidifier::entity_component::_::state::on", fallback: "On") }
  /// Idle
  public static var componentHumidifierEntityComponentStateAttributesActionStateIdle: String { return CoreStrings.tr("Core", "component::humidifier::entity_component::_::state_attributes::action::state::idle", fallback: "Idle") }
  /// Off
  public static var componentHumidifierEntityComponentStateAttributesActionStateOff: String { return CoreStrings.tr("Core", "component::humidifier::entity_component::_::state_attributes::action::state::off", fallback: "Off") }
  /// Home
  public static var componentHumidifierEntityComponentStateAttributesModeStateHome: String { return CoreStrings.tr("Core", "component::humidifier::entity_component::_::state_attributes::mode::state::home", fallback: "Home") }
  /// Device is already configured
  public static var componentImprovBleConfigAbortAlreadyConfigured: String { return CoreStrings.tr("Core", "component::improv_ble::config::abort::already_configured", fallback: "Device is already configured") }
  /// Failed to connect
  public static var componentImprovBleConfigAbortCannotConnect: String { return CoreStrings.tr("Core", "component::improv_ble::config::abort::cannot_connect", fallback: "Failed to connect") }
  /// The device is either already connected to Wi-Fi, or no longer able to connect to Wi-Fi. If you want to connect it to another network, try factory resetting it first.
  public static var componentImprovBleConfigAbortCharacteristicMissing: String { return CoreStrings.tr("Core", "component::improv_ble::config::abort::characteristic_missing", fallback: "The device is either already connected to Wi-Fi, or no longer able to connect to Wi-Fi. If you want to connect it to another network, try factory resetting it first.") }
  /// No devices found on the network
  public static var componentImprovBleConfigAbortNoDevicesFound: String { return CoreStrings.tr("Core", "component::improv_ble::config::abort::no_devices_found", fallback: "No devices found on the network") }
  /// The device has successfully connected to the Wi-Fi network.
  public static var componentImprovBleConfigAbortProvisionSuccessful: String { return CoreStrings.tr("Core", "component::improv_ble::config::abort::provision_successful", fallback: "The device has successfully connected to the Wi-Fi network.") }
  /// The device has successfully connected to the Wi-Fi network.
  /// 
  /// Please finish the setup by following the [setup instructions]({url}).
  public static var componentImprovBleConfigAbortProvisionSuccessfulUrl: String { return CoreStrings.tr("Core", "component::improv_ble::config::abort::provision_successful_url", fallback: "The device has successfully connected to the Wi-Fi network.\n\nPlease finish the setup by following the [setup instructions]({url}).") }
  /// Unexpected error
  public static var componentImprovBleConfigAbortUnknown: String { return CoreStrings.tr("Core", "component::improv_ble::config::abort::unknown", fallback: "Unexpected error") }
  /// The device could not connect to the Wi-Fi network. Check that the SSID and password are correct and try again.
  public static var componentImprovBleConfigErrorUnableToConnect: String { return CoreStrings.tr("Core", "component::improv_ble::config::error::unable_to_connect", fallback: "The device could not connect to the Wi-Fi network. Check that the SSID and password are correct and try again.") }
  /// {name}
  public static var componentImprovBleConfigFlowTitle: String { return CoreStrings.tr("Core", "component::improv_ble::config::flow_title", fallback: "{name}") }
  /// The device requires authorization, please press its authorization button or consult the device's manual for how to proceed.
  public static var componentImprovBleConfigProgressAuthorize: String { return CoreStrings.tr("Core", "component::improv_ble::config::progress::authorize", fallback: "The device requires authorization, please press its authorization button or consult the device's manual for how to proceed.") }
  /// The device is connecting to the Wi-Fi network.
  public static var componentImprovBleConfigProgressProvisioning: String { return CoreStrings.tr("Core", "component::improv_ble::config::progress::provisioning", fallback: "The device is connecting to the Wi-Fi network.") }
  /// Do you want to set up {name}?
  public static var componentImprovBleConfigStepBluetoothConfirmDescription: String { return CoreStrings.tr("Core", "component::improv_ble::config::step::bluetooth_confirm::description", fallback: "Do you want to set up {name}?") }
  /// The device is now identifying itself, for example by blinking or beeping.
  public static var componentImprovBleConfigStepIdentifyDescription: String { return CoreStrings.tr("Core", "component::improv_ble::config::step::identify::description", fallback: "The device is now identifying itself, for example by blinking or beeping.") }
  /// Choose next step.
  public static var componentImprovBleConfigStepMainMenuDescription: String { return CoreStrings.tr("Core", "component::improv_ble::config::step::main_menu::description", fallback: "Choose next step.") }
  /// Identify device
  public static var componentImprovBleConfigStepMainMenuMenuOptionsIdentify: String { return CoreStrings.tr("Core", "component::improv_ble::config::step::main_menu::menu_options::identify", fallback: "Identify device") }
  /// Connect device to a Wi-Fi network
  public static var componentImprovBleConfigStepMainMenuMenuOptionsProvision: String { return CoreStrings.tr("Core", "component::improv_ble::config::step::main_menu::menu_options::provision", fallback: "Connect device to a Wi-Fi network") }
  /// Password
  public static var componentImprovBleConfigStepProvisionDataPassword: String { return CoreStrings.tr("Core", "component::improv_ble::config::step::provision::data::password", fallback: "Password") }
  /// SSID
  public static var componentImprovBleConfigStepProvisionDataSsid: String { return CoreStrings.tr("Core", "component::improv_ble::config::step::provision::data::ssid", fallback: "SSID") }
  /// Enter Wi-Fi credentials to connect the device to your network.
  public static var componentImprovBleConfigStepProvisionDescription: String { return CoreStrings.tr("Core", "component::improv_ble::config::step::provision::description", fallback: "Enter Wi-Fi credentials to connect the device to your network.") }
  /// Device
  public static var componentImprovBleConfigStepUserDataAddress: String { return CoreStrings.tr("Core", "component::improv_ble::config::step::user::data::address", fallback: "Device") }
  /// Choose a device to set up
  public static var componentImprovBleConfigStepUserDescription: String { return CoreStrings.tr("Core", "component::improv_ble::config::step::user::description", fallback: "Choose a device to set up") }
  /// Off
  public static var componentInputBooleanEntityComponentStateOff: String { return CoreStrings.tr("Core", "component::input_boolean::entity_component::_::state::off", fallback: "Off") }
  /// On
  public static var componentInputBooleanEntityComponentStateOn: String { return CoreStrings.tr("Core", "component::input_boolean::entity_component::_::state::on", fallback: "On") }
  /// No
  public static var componentInputBooleanEntityComponentStateAttributesEditableStateFalse: String { return CoreStrings.tr("Core", "component::input_boolean::entity_component::_::state_attributes::editable::state::false", fallback: "No") }
  /// Yes
  public static var componentInputBooleanEntityComponentStateAttributesEditableStateTrue: String { return CoreStrings.tr("Core", "component::input_boolean::entity_component::_::state_attributes::editable::state::true", fallback: "Yes") }
  /// Input boolean
  public static var componentInputBooleanTitle: String { return CoreStrings.tr("Core", "component::input_boolean::title", fallback: "Input boolean") }
  /// No
  public static var componentInputButtonEntityComponentStateAttributesEditableStateFalse: String { return CoreStrings.tr("Core", "component::input_button::entity_component::_::state_attributes::editable::state::false", fallback: "No") }
  /// Yes
  public static var componentInputButtonEntityComponentStateAttributesEditableStateTrue: String { return CoreStrings.tr("Core", "component::input_button::entity_component::_::state_attributes::editable::state::true", fallback: "Yes") }
  /// Input button
  public static var componentInputButtonTitle: String { return CoreStrings.tr("Core", "component::input_button::title", fallback: "Input button") }
  /// No
  public static var componentInputDatetimeEntityComponentStateAttributesEditableStateFalse: String { return CoreStrings.tr("Core", "component::input_datetime::entity_component::_::state_attributes::editable::state::false", fallback: "No") }
  /// Yes
  public static var componentInputDatetimeEntityComponentStateAttributesEditableStateTrue: String { return CoreStrings.tr("Core", "component::input_datetime::entity_component::_::state_attributes::editable::state::true", fallback: "Yes") }
  /// No
  public static var componentInputNumberEntityComponentStateAttributesEditableStateFalse: String { return CoreStrings.tr("Core", "component::input_number::entity_component::_::state_attributes::editable::state::false", fallback: "No") }
  /// Yes
  public static var componentInputNumberEntityComponentStateAttributesEditableStateTrue: String { return CoreStrings.tr("Core", "component::input_number::entity_component::_::state_attributes::editable::state::true", fallback: "Yes") }
  /// No
  public static var componentInputSelectEntityComponentStateAttributesEditableStateFalse: String { return CoreStrings.tr("Core", "component::input_select::entity_component::_::state_attributes::editable::state::false", fallback: "No") }
  /// Yes
  public static var componentInputSelectEntityComponentStateAttributesEditableStateTrue: String { return CoreStrings.tr("Core", "component::input_select::entity_component::_::state_attributes::editable::state::true", fallback: "Yes") }
  /// No
  public static var componentInputTextEntityComponentStateAttributesEditableStateFalse: String { return CoreStrings.tr("Core", "component::input_text::entity_component::_::state_attributes::editable::state::false", fallback: "No") }
  /// Yes
  public static var componentInputTextEntityComponentStateAttributesEditableStateTrue: String { return CoreStrings.tr("Core", "component::input_text::entity_component::_::state_attributes::editable::state::true", fallback: "Yes") }
  /// Idle
  public static var componentIppEntitySensorPrinterStateIdle: String { return CoreStrings.tr("Core", "component::ipp::entity::sensor::printer::state::idle", fallback: "Idle") }
  /// Paused
  public static var componentLawnMowerEntityComponentStatePaused: String { return CoreStrings.tr("Core", "component::lawn_mower::entity_component::_::state::paused", fallback: "Paused") }
  /// Off
  public static var componentLightEntityComponentStateOff: String { return CoreStrings.tr("Core", "component::light::entity_component::_::state::off", fallback: "Off") }
  /// On
  public static var componentLightEntityComponentStateOn: String { return CoreStrings.tr("Core", "component::light::entity_component::_::state::on", fallback: "On") }
  /// Light
  public static var componentLightTitle: String { return CoreStrings.tr("Core", "component::light::title", fallback: "Light") }
  /// Off
  public static var componentLitterrobotEntitySensorStatusCodeStateOff: String { return CoreStrings.tr("Core", "component::litterrobot::entity::sensor::status_code::state::off", fallback: "Off") }
  /// Paused
  public static var componentLitterrobotEntitySensorStatusCodeStateP: String { return CoreStrings.tr("Core", "component::litterrobot::entity::sensor::status_code::state::p", fallback: "Paused") }
  /// Off
  public static var componentLitterrobotPlatformSensorStateLitterrobotStatusCodeOff: String { return CoreStrings.tr("Core", "component::litterrobot::platform::sensor::state::litterrobot__status_code::off", fallback: "Off") }
  /// Paused
  public static var componentLitterrobotPlatformSensorStateLitterrobotStatusCodeP: String { return CoreStrings.tr("Core", "component::litterrobot::platform::sensor::state::litterrobot__status_code::p", fallback: "Paused") }
  /// Enabled
  public static var componentLitterrobotServicesSetSleepModeFieldsEnabledName: String { return CoreStrings.tr("Core", "component::litterrobot::services::set_sleep_mode::fields::enabled::name", fallback: "Enabled") }
  /// Locked
  public static var componentLockEntityComponentStateLocked: String { return CoreStrings.tr("Core", "component::lock::entity_component::_::state::locked", fallback: "Locked") }
  /// Unlocked
  public static var componentLockEntityComponentStateUnlocked: String { return CoreStrings.tr("Core", "component::lock::entity_component::_::state::unlocked", fallback: "Unlocked") }
  /// Lock
  public static var componentLockTitle: String { return CoreStrings.tr("Core", "component::lock::title", fallback: "Lock") }
  /// Off
  public static var componentLutronCasetaDeviceAutomationTriggerSubtypeOff: String { return CoreStrings.tr("Core", "component::lutron_caseta::device_automation::trigger_subtype::off", fallback: "Off") }
  /// On
  public static var componentLutronCasetaDeviceAutomationTriggerSubtypeOn: String { return CoreStrings.tr("Core", "component::lutron_caseta::device_automation::trigger_subtype::on", fallback: "On") }
  /// Idle
  public static var componentMediaPlayerEntityComponentStateIdle: String { return CoreStrings.tr("Core", "component::media_player::entity_component::_::state::idle", fallback: "Idle") }
  /// Off
  public static var componentMediaPlayerEntityComponentStateOff: String { return CoreStrings.tr("Core", "component::media_player::entity_component::_::state::off", fallback: "Off") }
  /// On
  public static var componentMediaPlayerEntityComponentStateOn: String { return CoreStrings.tr("Core", "component::media_player::entity_component::_::state::on", fallback: "On") }
  /// Paused
  public static var componentMediaPlayerEntityComponentStatePaused: String { return CoreStrings.tr("Core", "component::media_player::entity_component::_::state::paused", fallback: "Paused") }
  /// Standby
  public static var componentMediaPlayerEntityComponentStateStandby: String { return CoreStrings.tr("Core", "component::media_player::entity_component::_::state::standby", fallback: "Standby") }
  /// No
  public static var componentMediaPlayerEntityComponentStateAttributesIsVolumeMutedStateFalse: String { return CoreStrings.tr("Core", "component::media_player::entity_component::_::state_attributes::is_volume_muted::state::false", fallback: "No") }
  /// Yes
  public static var componentMediaPlayerEntityComponentStateAttributesIsVolumeMutedStateTrue: String { return CoreStrings.tr("Core", "component::media_player::entity_component::_::state_attributes::is_volume_muted::state::true", fallback: "Yes") }
  /// Off
  public static var componentMediaPlayerEntityComponentStateAttributesRepeatStateOff: String { return CoreStrings.tr("Core", "component::media_player::entity_component::_::state_attributes::repeat::state::off", fallback: "Off") }
  /// Off
  public static var componentMediaPlayerEntityComponentStateAttributesShuffleStateFalse: String { return CoreStrings.tr("Core", "component::media_player::entity_component::_::state_attributes::shuffle::state::false", fallback: "Off") }
  /// On
  public static var componentMediaPlayerEntityComponentStateAttributesShuffleStateTrue: String { return CoreStrings.tr("Core", "component::media_player::entity_component::_::state_attributes::shuffle::state::true", fallback: "On") }
  /// Off
  public static var componentMqttSelectorSetCaCertOptionsOff: String { return CoreStrings.tr("Core", "component::mqtt::selector::set_ca_cert::options::off", fallback: "Off") }
  /// Away
  public static var componentNetatmoDeviceAutomationTriggerSubtypeAway: String { return CoreStrings.tr("Core", "component::netatmo::device_automation::trigger_subtype::away", fallback: "Away") }
  /// Away
  public static var componentOverkizEntityClimateOverkizStateAttributesFanModeStateAway: String { return CoreStrings.tr("Core", "component::overkiz::entity::climate::overkiz::state_attributes::fan_mode::state::away", fallback: "Away") }
  /// Closed
  public static var componentOverkizEntitySelectOpenClosedPartialStateClosed: String { return CoreStrings.tr("Core", "component::overkiz::entity::select::open_closed_partial::state::closed", fallback: "Closed") }
  /// Open
  public static var componentOverkizEntitySelectOpenClosedPartialStateOpen: String { return CoreStrings.tr("Core", "component::overkiz::entity::select::open_closed_partial::state::open", fallback: "Open") }
  /// Closed
  public static var componentOverkizEntitySelectOpenClosedPedestrianStateClosed: String { return CoreStrings.tr("Core", "component::overkiz::entity::select::open_closed_pedestrian::state::closed", fallback: "Closed") }
  /// Open
  public static var componentOverkizEntitySelectOpenClosedPedestrianStateOpen: String { return CoreStrings.tr("Core", "component::overkiz::entity::select::open_closed_pedestrian::state::open", fallback: "Open") }
  /// Closed
  public static var componentOverkizEntitySensorThreeWayHandleDirectionStateClosed: String { return CoreStrings.tr("Core", "component::overkiz::entity::sensor::three_way_handle_direction::state::closed", fallback: "Closed") }
  /// Open
  public static var componentOverkizEntitySensorThreeWayHandleDirectionStateOpen: String { return CoreStrings.tr("Core", "component::overkiz::entity::sensor::three_way_handle_direction::state::open", fallback: "Open") }
  /// Home
  public static var componentPersonEntityComponentStateHome: String { return CoreStrings.tr("Core", "component::person::entity_component::_::state::home", fallback: "Home") }
  /// Away
  public static var componentPersonEntityComponentStateNotHome: String { return CoreStrings.tr("Core", "component::person::entity_component::_::state::not_home", fallback: "Away") }
  /// Home
  public static var componentPlugwiseEntityClimatePlugwiseStateAttributesPresetModeStateHome: String { return CoreStrings.tr("Core", "component::plugwise::entity::climate::plugwise::state_attributes::preset_mode::state::home", fallback: "Home") }
  /// Off
  public static var componentPlugwiseEntitySelectDhwModeStateOff: String { return CoreStrings.tr("Core", "component::plugwise::entity::select::dhw_mode::state::off", fallback: "Off") }
  /// Off
  public static var componentPlugwiseEntitySelectRegulationModeStateOff: String { return CoreStrings.tr("Core", "component::plugwise::entity::select::regulation_mode::state::off", fallback: "Off") }
  /// Idle
  public static var componentPrusalinkEntitySensorPrinterStateStateIdle: String { return CoreStrings.tr("Core", "component::prusalink::entity::sensor::printer_state::state::idle", fallback: "Idle") }
  /// Paused
  public static var componentPrusalinkEntitySensorPrinterStateStatePaused: String { return CoreStrings.tr("Core", "component::prusalink::entity::sensor::printer_state::state::paused", fallback: "Paused") }
  /// Off
  public static var componentRemoteEntityComponentStateOff: String { return CoreStrings.tr("Core", "component::remote::entity_component::_::state::off", fallback: "Off") }
  /// On
  public static var componentRemoteEntityComponentStateOn: String { return CoreStrings.tr("Core", "component::remote::entity_component::_::state::on", fallback: "On") }
  /// Off
  public static var componentRensonEntitySensorBreezeLevelStateOff: String { return CoreStrings.tr("Core", "component::renson::entity::sensor::breeze_level::state::off", fallback: "Off") }
  /// Off
  public static var componentRensonEntitySensorManualLevelStateOff: String { return CoreStrings.tr("Core", "component::renson::entity::sensor::manual_level::state::off", fallback: "Off") }
  /// Off
  public static var componentRensonEntitySensorVentilationLevelStateOff: String { return CoreStrings.tr("Core", "component::renson::entity::sensor::ventilation_level::state::off", fallback: "Off") }
  /// Off
  public static var componentRensonSelectorLevelSettingOptionsOff: String { return CoreStrings.tr("Core", "component::renson::selector::level_setting::options::off", fallback: "Off") }
  /// Off
  public static var componentReolinkEntitySelectAutoQuickReplyMessageStateOff: String { return CoreStrings.tr("Core", "component::reolink::entity::select::auto_quick_reply_message::state::off", fallback: "Off") }
  /// Off
  public static var componentReolinkEntitySelectFloodlightModeStateOff: String { return CoreStrings.tr("Core", "component::reolink::entity::select::floodlight_mode::state::off", fallback: "Off") }
  /// Off
  public static var componentRoborockEntitySelectMopIntensityStateOff: String { return CoreStrings.tr("Core", "component::roborock::entity::select::mop_intensity::state::off", fallback: "Off") }
  /// Idle
  public static var componentRoborockEntitySensorStatusStateIdle: String { return CoreStrings.tr("Core", "component::roborock::entity::sensor::status::state::idle", fallback: "Idle") }
  /// Paused
  public static var componentRoborockEntitySensorStatusStatePaused: String { return CoreStrings.tr("Core", "component::roborock::entity::sensor::status::state::paused", fallback: "Paused") }
  /// Off
  public static var componentRoborockEntityVacuumRoborockStateAttributesFanSpeedStateOff: String { return CoreStrings.tr("Core", "component::roborock::entity::vacuum::roborock::state_attributes::fan_speed::state::off", fallback: "Off") }
  /// Scene
  public static var componentSceneTitle: String { return CoreStrings.tr("Core", "component::scene::title", fallback: "Scene") }
  /// Off
  public static var componentScheduleEntityComponentStateOff: String { return CoreStrings.tr("Core", "component::schedule::entity_component::_::state::off", fallback: "Off") }
  /// On
  public static var componentScheduleEntityComponentStateOn: String { return CoreStrings.tr("Core", "component::schedule::entity_component::_::state::on", fallback: "On") }
  /// No
  public static var componentScheduleEntityComponentStateAttributesEditableStateFalse: String { return CoreStrings.tr("Core", "component::schedule::entity_component::_::state_attributes::editable::state::false", fallback: "No") }
  /// Yes
  public static var componentScheduleEntityComponentStateAttributesEditableStateTrue: String { return CoreStrings.tr("Core", "component::schedule::entity_component::_::state_attributes::editable::state::true", fallback: "Yes") }
  /// Off
  public static var componentScriptEntityComponentStateOff: String { return CoreStrings.tr("Core", "component::script::entity_component::_::state::off", fallback: "Off") }
  /// On
  public static var componentScriptEntityComponentStateOn: String { return CoreStrings.tr("Core", "component::script::entity_component::_::state::on", fallback: "On") }
  /// Script
  public static var componentScriptTitle: String { return CoreStrings.tr("Core", "component::script::title", fallback: "Script") }
  /// Off
  public static var componentSensiboEntityClimateClimateDeviceStateAttributesSwingModeStateStopped: String { return CoreStrings.tr("Core", "component::sensibo::entity::climate::climate_device::state_attributes::swing_mode::state::stopped", fallback: "Off") }
  /// Off
  public static var componentSensiboEntitySelectHorizontalswingStateStopped: String { return CoreStrings.tr("Core", "component::sensibo::entity::select::horizontalswing::state::stopped", fallback: "Off") }
  /// Off
  public static var componentSensiboEntitySelectLightStateOff: String { return CoreStrings.tr("Core", "component::sensibo::entity::select::light::state::off", fallback: "Off") }
  /// On
  public static var componentSensiboEntitySelectLightStateOn: String { return CoreStrings.tr("Core", "component::sensibo::entity::select::light::state::on", fallback: "On") }
  /// Off
  public static var componentSensiboEntitySensorClimateReactHighStateAttributesHorizontalswingStateStopped: String { return CoreStrings.tr("Core", "component::sensibo::entity::sensor::climate_react_high::state_attributes::horizontalswing::state::stopped", fallback: "Off") }
  /// Off
  public static var componentSensiboEntitySensorClimateReactHighStateAttributesLightStateOff: String { return CoreStrings.tr("Core", "component::sensibo::entity::sensor::climate_react_high::state_attributes::light::state::off", fallback: "Off") }
  /// On
  public static var componentSensiboEntitySensorClimateReactHighStateAttributesLightStateOn: String { return CoreStrings.tr("Core", "component::sensibo::entity::sensor::climate_react_high::state_attributes::light::state::on", fallback: "On") }
  /// Off
  public static var componentSensiboEntitySensorClimateReactHighStateAttributesModeStateOff: String { return CoreStrings.tr("Core", "component::sensibo::entity::sensor::climate_react_high::state_attributes::mode::state::off", fallback: "Off") }
  /// On
  public static var componentSensiboEntitySensorClimateReactHighStateAttributesOnName: String { return CoreStrings.tr("Core", "component::sensibo::entity::sensor::climate_react_high::state_attributes::on::name", fallback: "On") }
  /// Off
  public static var componentSensiboEntitySensorClimateReactHighStateAttributesOnStateFalse: String { return CoreStrings.tr("Core", "component::sensibo::entity::sensor::climate_react_high::state_attributes::on::state::false", fallback: "Off") }
  /// On
  public static var componentSensiboEntitySensorClimateReactHighStateAttributesOnStateTrue: String { return CoreStrings.tr("Core", "component::sensibo::entity::sensor::climate_react_high::state_attributes::on::state::true", fallback: "On") }
  /// Off
  public static var componentSensiboEntitySensorClimateReactHighStateAttributesSwingStateStopped: String { return CoreStrings.tr("Core", "component::sensibo::entity::sensor::climate_react_high::state_attributes::swing::state::stopped", fallback: "Off") }
  /// Off
  public static var componentSensiboEntitySensorClimateReactLowStateAttributesHorizontalswingStateStopped: String { return CoreStrings.tr("Core", "component::sensibo::entity::sensor::climate_react_low::state_attributes::horizontalswing::state::stopped", fallback: "Off") }
  /// Off
  public static var componentSensiboEntitySensorClimateReactLowStateAttributesLightStateOff: String { return CoreStrings.tr("Core", "component::sensibo::entity::sensor::climate_react_low::state_attributes::light::state::off", fallback: "Off") }
  /// On
  public static var componentSensiboEntitySensorClimateReactLowStateAttributesLightStateOn: String { return CoreStrings.tr("Core", "component::sensibo::entity::sensor::climate_react_low::state_attributes::light::state::on", fallback: "On") }
  /// Off
  public static var componentSensiboEntitySensorClimateReactLowStateAttributesModeStateOff: String { return CoreStrings.tr("Core", "component::sensibo::entity::sensor::climate_react_low::state_attributes::mode::state::off", fallback: "Off") }
  /// On
  public static var componentSensiboEntitySensorClimateReactLowStateAttributesOnName: String { return CoreStrings.tr("Core", "component::sensibo::entity::sensor::climate_react_low::state_attributes::on::name", fallback: "On") }
  /// Off
  public static var componentSensiboEntitySensorClimateReactLowStateAttributesOnStateFalse: String { return CoreStrings.tr("Core", "component::sensibo::entity::sensor::climate_react_low::state_attributes::on::state::false", fallback: "Off") }
  /// On
  public static var componentSensiboEntitySensorClimateReactLowStateAttributesOnStateTrue: String { return CoreStrings.tr("Core", "component::sensibo::entity::sensor::climate_react_low::state_attributes::on::state::true", fallback: "On") }
  /// Off
  public static var componentSensiboEntitySensorClimateReactLowStateAttributesSwingStateStopped: String { return CoreStrings.tr("Core", "component::sensibo::entity::sensor::climate_react_low::state_attributes::swing::state::stopped", fallback: "Off") }
  /// Off
  public static var componentSensiboEntitySwitchTimerOnSwitchStateAttributesTurnOnStateFalse: String { return CoreStrings.tr("Core", "component::sensibo::entity::switch::timer_on_switch::state_attributes::turn_on::state::false", fallback: "Off") }
  /// On
  public static var componentSensiboEntitySwitchTimerOnSwitchStateAttributesTurnOnStateTrue: String { return CoreStrings.tr("Core", "component::sensibo::entity::switch::timer_on_switch::state_attributes::turn_on::state::true", fallback: "On") }
  /// Off
  public static var componentSensorEntityComponentStateOff: String { return CoreStrings.tr("Core", "component::sensor::entity_component::_::state::off", fallback: "Off") }
  /// On
  public static var componentSensorEntityComponentStateOn: String { return CoreStrings.tr("Core", "component::sensor::entity_component::_::state::on", fallback: "On") }
  /// Idle
  public static var componentSfrBoxEntitySensorDslTrainingStateIdle: String { return CoreStrings.tr("Core", "component::sfr_box::entity::sensor::dsl_training::state::idle", fallback: "Idle") }
  /// Closed
  public static var componentShellyEntitySensorValveStatusStateClosed: String { return CoreStrings.tr("Core", "component::shelly::entity::sensor::valve_status::state::closed", fallback: "Closed") }
  /// Active
  public static var componentShellySelectorBleScannerModeOptionsActive: String { return CoreStrings.tr("Core", "component::shelly::selector::ble_scanner_mode::options::active", fallback: "Active") }
  /// Disabled
  public static var componentShellySelectorBleScannerModeOptionsDisabled: String { return CoreStrings.tr("Core", "component::shelly::selector::ble_scanner_mode::options::disabled", fallback: "Disabled") }
  /// Off
  public static var componentSirenEntityComponentStateOff: String { return CoreStrings.tr("Core", "component::siren::entity_component::_::state::off", fallback: "Off") }
  /// On
  public static var componentSirenEntityComponentStateOn: String { return CoreStrings.tr("Core", "component::siren::entity_component::_::state::on", fallback: "On") }
  /// Sleep
  public static var componentStarlinkEntityBinarySensorPowerSaveIdleName: String { return CoreStrings.tr("Core", "component::starlink::entity::binary_sensor::power_save_idle::name", fallback: "Sleep") }
  /// Off
  public static var componentSwitchEntityComponentStateOff: String { return CoreStrings.tr("Core", "component::switch::entity_component::_::state::off", fallback: "Off") }
  /// On
  public static var componentSwitchEntityComponentStateOn: String { return CoreStrings.tr("Core", "component::switch::entity_component::_::state::on", fallback: "On") }
  /// Switch
  public static var componentSwitchTitle: String { return CoreStrings.tr("Core", "component::switch::title", fallback: "Switch") }
  /// Off
  public static var componentTessieEntitySelectClimateStateSeatHeaterLeftStateOff: String { return CoreStrings.tr("Core", "component::tessie::entity::select::climate_state_seat_heater_left::state::off", fallback: "Off") }
  /// Off
  public static var componentTessieEntitySelectClimateStateSeatHeaterRearCenterStateOff: String { return CoreStrings.tr("Core", "component::tessie::entity::select::climate_state_seat_heater_rear_center::state::off", fallback: "Off") }
  /// Off
  public static var componentTessieEntitySelectClimateStateSeatHeaterRearLeftStateOff: String { return CoreStrings.tr("Core", "component::tessie::entity::select::climate_state_seat_heater_rear_left::state::off", fallback: "Off") }
  /// Off
  public static var componentTessieEntitySelectClimateStateSeatHeaterRearRightStateOff: String { return CoreStrings.tr("Core", "component::tessie::entity::select::climate_state_seat_heater_rear_right::state::off", fallback: "Off") }
  /// Off
  public static var componentTessieEntitySelectClimateStateSeatHeaterRightStateOff: String { return CoreStrings.tr("Core", "component::tessie::entity::select::climate_state_seat_heater_right::state::off", fallback: "Off") }
  /// Off
  public static var componentTessieEntitySelectClimateStateSeatHeaterThirdRowLeftStateOff: String { return CoreStrings.tr("Core", "component::tessie::entity::select::climate_state_seat_heater_third_row_left::state::off", fallback: "Off") }
  /// Off
  public static var componentTessieEntitySelectClimateStateSeatHeaterThirdRowRightStateOff: String { return CoreStrings.tr("Core", "component::tessie::entity::select::climate_state_seat_heater_third_row_right::state::off", fallback: "Off") }
  /// Active
  public static var componentTimerEntityComponentStateActive: String { return CoreStrings.tr("Core", "component::timer::entity_component::_::state::active", fallback: "Active") }
  /// Idle
  public static var componentTimerEntityComponentStateIdle: String { return CoreStrings.tr("Core", "component::timer::entity_component::_::state::idle", fallback: "Idle") }
  /// Paused
  public static var componentTimerEntityComponentStatePaused: String { return CoreStrings.tr("Core", "component::timer::entity_component::_::state::paused", fallback: "Paused") }
  /// No
  public static var componentTimerEntityComponentStateAttributesEditableStateFalse: String { return CoreStrings.tr("Core", "component::timer::entity_component::_::state_attributes::editable::state::false", fallback: "No") }
  /// Yes
  public static var componentTimerEntityComponentStateAttributesEditableStateTrue: String { return CoreStrings.tr("Core", "component::timer::entity_component::_::state_attributes::editable::state::true", fallback: "Yes") }
  /// Idle
  public static var componentTransmissionEntitySensorTransmissionStatusStateIdle: String { return CoreStrings.tr("Core", "component::transmission::entity::sensor::transmission_status::state::idle", fallback: "Idle") }
  /// Disabled
  public static var componentTuyaEntitySelectBasicAntiFlickerState0: String { return CoreStrings.tr("Core", "component::tuya::entity::select::basic_anti_flicker::state:::0", fallback: "Disabled") }
  /// Off
  public static var componentTuyaEntitySelectBasicNightvisionState1: String { return CoreStrings.tr("Core", "component::tuya::entity::select::basic_nightvision::state:::1", fallback: "Off") }
  /// On
  public static var componentTuyaEntitySelectBasicNightvisionState2: String { return CoreStrings.tr("Core", "component::tuya::entity::select::basic_nightvision::state:::2", fallback: "On") }
  /// Off
  public static var componentTuyaEntitySelectLightModeStateNone: String { return CoreStrings.tr("Core", "component::tuya::entity::select::light_mode::state::none", fallback: "Off") }
  /// Off
  public static var componentTuyaEntitySelectRelayStatusStateOff: String { return CoreStrings.tr("Core", "component::tuya::entity::select::relay_status::state::off", fallback: "Off") }
  /// On
  public static var componentTuyaEntitySelectRelayStatusStateOn: String { return CoreStrings.tr("Core", "component::tuya::entity::select::relay_status::state::on", fallback: "On") }
  /// Off
  public static var componentTuyaEntitySelectRelayStatusStatePowerOff: String { return CoreStrings.tr("Core", "component::tuya::entity::select::relay_status::state::power_off", fallback: "Off") }
  /// On
  public static var componentTuyaEntitySelectRelayStatusStatePowerOn: String { return CoreStrings.tr("Core", "component::tuya::entity::select::relay_status::state::power_on", fallback: "On") }
  /// Closed
  public static var componentTuyaEntitySelectVacuumCisternStateClosed: String { return CoreStrings.tr("Core", "component::tuya::entity::select::vacuum_cistern::state::closed", fallback: "Closed") }
  /// Standby
  public static var componentTuyaEntitySelectVacuumModeStateStandby: String { return CoreStrings.tr("Core", "component::tuya::entity::select::vacuum_mode::state::standby", fallback: "Standby") }
  /// Standby
  public static var componentTuyaEntitySensorSousVideStatusStateStandby: String { return CoreStrings.tr("Core", "component::tuya::entity::sensor::sous_vide_status::state::standby", fallback: "Standby") }
  /// Off
  public static var componentTuyaPlatformSelectStateTuyaLightModeNone: String { return CoreStrings.tr("Core", "component::tuya::platform::select::state::tuya__light_mode::none", fallback: "Off") }
  /// Off
  public static var componentTuyaPlatformSelectStateTuyaRelayStatusOff: String { return CoreStrings.tr("Core", "component::tuya::platform::select::state::tuya__relay_status::off", fallback: "Off") }
  /// On
  public static var componentTuyaPlatformSelectStateTuyaRelayStatusOn: String { return CoreStrings.tr("Core", "component::tuya::platform::select::state::tuya__relay_status::on", fallback: "On") }
  /// Off
  public static var componentTuyaPlatformSelectStateTuyaRelayStatusPowerOff: String { return CoreStrings.tr("Core", "component::tuya::platform::select::state::tuya__relay_status::power_off", fallback: "Off") }
  /// On
  public static var componentTuyaPlatformSelectStateTuyaRelayStatusPowerOn: String { return CoreStrings.tr("Core", "component::tuya::platform::select::state::tuya__relay_status::power_on", fallback: "On") }
  /// Closed
  public static var componentTuyaPlatformSelectStateTuyaVacuumCisternClosed: String { return CoreStrings.tr("Core", "component::tuya::platform::select::state::tuya__vacuum_cistern::closed", fallback: "Closed") }
  /// No
  public static var componentUpdateEntityComponentStateAttributesAutoUpdateStateFalse: String { return CoreStrings.tr("Core", "component::update::entity_component::_::state_attributes::auto_update::state::false", fallback: "No") }
  /// Yes
  public static var componentUpdateEntityComponentStateAttributesAutoUpdateStateTrue: String { return CoreStrings.tr("Core", "component::update::entity_component::_::state_attributes::auto_update::state::true", fallback: "Yes") }
  /// No
  public static var componentUpdateEntityComponentStateAttributesInProgressStateFalse: String { return CoreStrings.tr("Core", "component::update::entity_component::_::state_attributes::in_progress::state::false", fallback: "No") }
  /// Yes
  public static var componentUpdateEntityComponentStateAttributesInProgressStateTrue: String { return CoreStrings.tr("Core", "component::update::entity_component::_::state_attributes::in_progress::state::true", fallback: "Yes") }
  /// Idle
  public static var componentVacuumEntityComponentStateIdle: String { return CoreStrings.tr("Core", "component::vacuum::entity_component::_::state::idle", fallback: "Idle") }
  /// Off
  public static var componentVacuumEntityComponentStateOff: String { return CoreStrings.tr("Core", "component::vacuum::entity_component::_::state::off", fallback: "Off") }
  /// On
  public static var componentVacuumEntityComponentStateOn: String { return CoreStrings.tr("Core", "component::vacuum::entity_component::_::state::on", fallback: "On") }
  /// Paused
  public static var componentVacuumEntityComponentStatePaused: String { return CoreStrings.tr("Core", "component::vacuum::entity_component::_::state::paused", fallback: "Paused") }
  /// Closed
  public static var componentValveEntityComponentStateClosed: String { return CoreStrings.tr("Core", "component::valve::entity_component::_::state::closed", fallback: "Closed") }
  /// Open
  public static var componentValveEntityComponentStateOpen: String { return CoreStrings.tr("Core", "component::valve::entity_component::_::state::open", fallback: "Open") }
  /// Off
  public static var componentWaterHeaterEntityComponentStateOff: String { return CoreStrings.tr("Core", "component::water_heater::entity_component::_::state::off", fallback: "Off") }
  /// Off
  public static var componentWaterHeaterEntityComponentStateAttributesAwayModeStateOff: String { return CoreStrings.tr("Core", "component::water_heater::entity_component::_::state_attributes::away_mode::state::off", fallback: "Off") }
  /// On
  public static var componentWaterHeaterEntityComponentStateAttributesAwayModeStateOn: String { return CoreStrings.tr("Core", "component::water_heater::entity_component::_::state_attributes::away_mode::state::on", fallback: "On") }
  /// Paused
  public static var componentWhirlpoolEntitySensorWhirlpoolMachineStatePause: String { return CoreStrings.tr("Core", "component::whirlpool::entity::sensor::whirlpool_machine::state::pause", fallback: "Paused") }
  /// Standby
  public static var componentWhirlpoolEntitySensorWhirlpoolMachineStateStandby: String { return CoreStrings.tr("Core", "component::whirlpool::entity::sensor::whirlpool_machine::state::standby", fallback: "Standby") }
  /// Active
  public static var componentWhirlpoolEntitySensorWhirlpoolTankStateActive: String { return CoreStrings.tr("Core", "component::whirlpool::entity::sensor::whirlpool_tank::state::active", fallback: "Active") }
  /// Off
  public static var componentWledEntitySelectLiveOverrideState0: String { return CoreStrings.tr("Core", "component::wled::entity::select::live_override::state:::0", fallback: "Off") }
  /// On
  public static var componentWledEntitySelectLiveOverrideState1: String { return CoreStrings.tr("Core", "component::wled::entity::select::live_override::state:::1", fallback: "On") }
  /// Off
  public static var componentWolflinkEntitySensorStateStateAus: String { return CoreStrings.tr("Core", "component::wolflink::entity::sensor::state::state::aus", fallback: "Off") }
  /// On
  public static var componentWolflinkEntitySensorStateStateEin: String { return CoreStrings.tr("Core", "component::wolflink::entity::sensor::state::state::ein", fallback: "On") }
  /// Standby
  public static var componentWolflinkEntitySensorStateStateStandby: String { return CoreStrings.tr("Core", "component::wolflink::entity::sensor::state::state::standby", fallback: "Standby") }
  /// Off
  public static var componentXiaomiMiioEntitySelectLedBrightnessStateOff: String { return CoreStrings.tr("Core", "component::xiaomi_miio::entity::select::led_brightness::state::off", fallback: "Off") }
  /// Enabled
  public static var componentYamahaServicesEnableOutputFieldsEnabledName: String { return CoreStrings.tr("Core", "component::yamaha::services::enable_output::fields::enabled::name", fallback: "Enabled") }
  /// Off
  public static var componentYamahaMusiccastEntitySelectZoneSleepStateOff: String { return CoreStrings.tr("Core", "component::yamaha_musiccast::entity::select::zone_sleep::state::off", fallback: "Off") }
  /// Off
  public static var componentYeelightSelectorActionOptionsOff: String { return CoreStrings.tr("Core", "component::yeelight::selector::action::options::off", fallback: "Off") }
  /// Off
  public static var componentYolinkEntitySensorPowerFailureAlarmStateOff: String { return CoreStrings.tr("Core", "component::yolink::entity::sensor::power_failure_alarm::state::off", fallback: "Off") }
  /// Disabled
  public static var componentYolinkEntitySensorPowerFailureAlarmBeepStateDisabled: String { return CoreStrings.tr("Core", "component::yolink::entity::sensor::power_failure_alarm_beep::state::disabled", fallback: "Disabled") }
  /// Enabled
  public static var componentYolinkEntitySensorPowerFailureAlarmBeepStateEnabled: String { return CoreStrings.tr("Core", "component::yolink::entity::sensor::power_failure_alarm_beep::state::enabled", fallback: "Enabled") }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension CoreStrings {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg..., fallback value: String) -> String {
    let format = Current.localized.string(key, table, value)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}
