___TERMS_OF_SERVICE___

By creating or modifying this file you agree to Google Tag Manager's Community
Template Gallery Developer Terms of Service available at
https://developers.google.com/tag-manager/gallery-tos (or such other URL as
Google may provide), as modified from time to time.


___INFO___

{
  "type": "TAG",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "Tapper - Conversion Script",
  "brand": {
    "id": "brand_dummy",
    "displayName": ""
  },
  "description": "Records a conversion event via the Tapper monitoring script.",
  "categories": ["CONVERSIONS", "ADVERTISING"],
  "containerContexts": [
    "WEB"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "pk",
    "displayName": "Public Key (pk)",
    "simpleValueType": true
  },
  {
    "type": "TEXT",
    "name": "conversion",
    "displayName": "Conversion Value",
    "simpleValueType": true,
    "defaultValue": "1",
    "help": "The conversion value to record. Defaults to 1."
  },
  {
    "type": "TEXT",
    "name": "orderValue",
    "displayName": "Order Value",
    "simpleValueType": true,
    "help": "Map your order total variable, e.g. {{Ecommerce Value}}. Must be a number. Leave empty to record a plain conversion (legacy behaviour)."
  },
  {
    "type": "TEXT",
    "name": "currency",
    "displayName": "Currency",
    "simpleValueType": true,
    "help": "Optional. 3-letter code, e.g. EUR. Leave empty to use your ad account's currency."
  },
  {
    "type": "TEXT",
    "name": "transactionId",
    "displayName": "Transaction ID",
    "simpleValueType": true,
    "help": "Optional. Your order/transaction id. Enables value corrections."
  },
  {
    "type": "SIMPLE_TABLE",
    "name": "additionalFields",
    "displayName": "Additional fields",
    "simpleTableColumns": [
      {
        "type": "TEXT",
        "name": "name",
        "displayName": "Name",
        "isUnique": true
      },
      {
        "type": "TEXT",
        "name": "value",
        "displayName": "Value",
        "valueHint": "{{Your variable}}"
      }
    ],
    "help": "Optional. Extra details about the transaction, sent with the conversion: one row per field. Name: start with a letter, then letters, numbers or underscores, up to 40 characters (lowercase with underscores is suggested, for example partner_purchase). Value: map one of your GTM variables, or type text of up to 100 characters, a number, or true or false. The first 20 fields are kept. A row with an empty name, or whose variable has no value, is skipped. A field we cannot accept is dropped on its own: the conversion, its value, its currency and its order id are always recorded. Send facts about the transaction, never details about the person: a value that looks like an email address, a phone number or a street address, and a field named like email, phone, msisdn, name or address, is not stored."
  },
  {
    "type": "CHECKBOX",
    "name": "sendOrderIdWithZeroValue",
    "checkboxText": "Send the order id when the order value is 0",
    "simpleValueType": true,
    "defaultValue": false,
    "help": "Off by default. When on, an order whose Order Value is exactly 0 (e.g. a fully discounted or free order) is recorded with value 0, its currency and its Transaction ID, instead of as a plain conversion without an order id. Only applies when the Transaction ID is set. Negative, non-numeric and empty Order Values still record a plain conversion."
  }
]


___SANDBOXED_JS_FOR_WEB_TEMPLATE___

const injectScript = require('injectScript');
const callInWindow = require('callInWindow');
const logToConsole = require('logToConsole');
const copyFromWindow = require('copyFromWindow');

const scriptUrl = 'https://monitor.tapper.ai/bundle.js';
const pk = data.pk;
const makeNumber = require('makeNumber');
const makeString = require('makeString');
const getType = require('getType');
// makeNumber returns NaN for non-numeric input (e.g. a misconfigured tag with
// Conversion Value "abc"). NaN must never reach tapper.push — fall back to the
// legacy default of 1. NaN is the only value not equal to itself, and the
// sandbox has no isNaN API. Beyond NaN, the legacy Conversion Value must also
// be range-guarded: negative, zero, Infinity, or absurdly large amounts must
// fall back to 1 rather than being pushed as-is.
// maxOrderValue is the shared upper bound for BOTH the legacy Conversion Value
// and the Order Value paths, so it is declared before either use.
const maxOrderValue = 9999999999;
const rawConversion = data.conversion !== undefined && data.conversion !== '' ? makeNumber(data.conversion) : 1;
const conversionIsValid = rawConversion === rawConversion && rawConversion > 0 && rawConversion <= maxOrderValue;
const conversion = conversionIsValid ? rawConversion : 1;

// Order Value must be a positive finite number to record a value. Anything
// else falls back to the legacy conversion path — never drop the conversion.
const hasOrderValue = data.orderValue !== undefined && data.orderValue !== '';
const orderValue = hasOrderValue ? makeNumber(data.orderValue) : undefined;
const orderValueIsValid = hasOrderValue && orderValue > 0 && orderValue <= maxOrderValue;

// Opt-in (checkbox, default off): an Order Value of exactly 0 ('0', '0.00', 0)
// with a non-empty Transaction ID records value 0 with its order id instead of
// the legacy conversion, which carries no order id. Zero means the number 0 or
// a string holding a 0 digit: a blank string or false also coerce to 0, but
// they are a misconfigured variable, not a zero-value order. The id always
// goes as a string (makeString), so a numeric-looking id never becomes a
// number. With the box off every input pushes exactly what it pushed before.
const orderValueType = getType(data.orderValue);
const orderValueIsZero = hasOrderValue && orderValue === 0 &&
  (orderValueType === 'number' || (orderValueType === 'string' && data.orderValue.indexOf('0') !== -1));
const zeroValueOrderId = data.transactionId !== undefined && data.transactionId !== null ? makeString(data.transactionId) : '';
const sendZeroValueOrder = data.sendOrderIdWithZeroValue === true && orderValueIsZero && zeroValueOrderId !== '';

// Additional fields (optional SIMPLE_TABLE): one plain object built from the
// rows and passed as the 4th argument of tapper.push. A row with an empty
// name, or whose value variable resolved to nothing, is skipped here; every
// other rule (name shape, length, type, how many are kept) is applied where
// the conversion is received, so a field we cannot accept is dropped on its
// own and never costs the conversion. Values go as the types GTM produced:
// no coercion, so a number stays a number and a boolean stays a boolean.
// hasAdditionalFields gates the 4th argument: with no fields every call below
// is byte-identical to the call this template made before the option existed.
const additionalFieldRows = getType(data.additionalFields) === 'array' ? data.additionalFields : [];
const additionalFields = {};
var additionalFieldCount = 0;
for (var i = 0; i < additionalFieldRows.length; i++) {
  const row = additionalFieldRows[i];
  const fieldName = getType(row) === 'object' && row.name !== undefined && row.name !== null ? makeString(row.name) : '';
  if (fieldName !== '' && row.value !== undefined && row.value !== null) {
    additionalFields[fieldName] = row.value;
    additionalFieldCount++;
  }
}
const hasAdditionalFields = additionalFieldCount > 0;

if (!pk) {
  logToConsole('Tapper: public key (pk) is missing');
  data.gtmOnFailure();
  return;
}

if (!conversionIsValid) {
  logToConsole('Tapper: Conversion Value is not a number, recording the conversion as 1');
}

if (hasOrderValue && !orderValueIsValid && !sendZeroValueOrder) {
  logToConsole('Tapper: Order Value is not a positive number, recording the conversion without a value');
}

function recordConversion() {
  if (orderValueIsValid) {
    if (hasAdditionalFields) {
      callInWindow('tapper.push', orderValue, data.currency || undefined, data.transactionId || undefined, additionalFields);
    } else {
      callInWindow('tapper.push', orderValue, data.currency || undefined, data.transactionId || undefined);
    }
  } else if (sendZeroValueOrder) {
    if (hasAdditionalFields) {
      callInWindow('tapper.push', 0, data.currency || undefined, zeroValueOrderId, additionalFields);
    } else {
      callInWindow('tapper.push', 0, data.currency || undefined, zeroValueOrderId);
    }
  } else {
    if (hasAdditionalFields) {
      callInWindow('tapper.push', conversion, undefined, undefined, additionalFields);
    } else {
      callInWindow('tapper.push', conversion);
    }
  }
  data.gtmOnSuccess();
}

var tapperExists = copyFromWindow('tapper');

if (tapperExists) {
  recordConversion();
} else {
  injectScript(
    scriptUrl,
    function () {
      callInWindow('tapper.init', pk);
      recordConversion();
    },
    function () {
      logToConsole('Tapper: failed to load script');
      data.gtmOnFailure();
    },
    'tapper-monitor-script'
  );
}


___WEB_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "all"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "inject_script",
        "versionId": "1"
      },
      "param": [
        {
          "key": "urls",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "https://monitor.tapper.ai/"
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_globals",
        "versionId": "1"
      },
      "param": [
        {
          "key": "keys",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {"type": 1, "string": "key"},
                  {"type": 1, "string": "read"},
                  {"type": 1, "string": "write"},
                  {"type": 1, "string": "execute"}
                ],
                "mapValue": [
                  {"type": 1, "string": "tapper"},
                  {"type": 8, "boolean": true},
                  {"type": 8, "boolean": false},
                  {"type": 8, "boolean": false}
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {"type": 1, "string": "key"},
                  {"type": 1, "string": "read"},
                  {"type": 1, "string": "write"},
                  {"type": 1, "string": "execute"}
                ],
                "mapValue": [
                  {"type": 1, "string": "tapper.init"},
                  {"type": 8, "boolean": false},
                  {"type": 8, "boolean": false},
                  {"type": 8, "boolean": true}
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {"type": 1, "string": "key"},
                  {"type": 1, "string": "read"},
                  {"type": 1, "string": "write"},
                  {"type": 1, "string": "execute"}
                ],
                "mapValue": [
                  {"type": 1, "string": "tapper.push"},
                  {"type": 8, "boolean": false},
                  {"type": 8, "boolean": false},
                  {"type": 8, "boolean": true}
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios:
- name: Records conversion with default value
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '',
      gtmOnSuccess: () => {},
      gtmOnFailure: () => fail('gtmOnFailure should not be called')
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
- name: Records conversion with custom value
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '5',
      gtmOnSuccess: () => {},
      gtmOnFailure: () => fail('gtmOnFailure should not be called')
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
- name: Fails without pk
  code: |-
    const mockData = {
      pk: '',
      conversion: '1',
      gtmOnSuccess: () => fail('gtmOnSuccess should not be called'),
      gtmOnFailure: () => {}
    };
    runCode(mockData);
    assertApi('gtmOnFailure').wasCalled();
- name: Legacy fire when Order Value is empty
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '',
      orderValue: '',
      currency: '',
      transactionId: '',
      gtmOnSuccess: () => {},
      gtmOnFailure: () => fail('gtmOnFailure should not be called')
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 1);
- name: Rich fire with value and currency
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: '49.99',
      currency: 'EUR',
      transactionId: 'ORD-1',
      gtmOnSuccess: () => {},
      gtmOnFailure: () => fail('gtmOnFailure should not be called')
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 49.99, 'EUR', 'ORD-1');
- name: Rich fire without currency uses account default
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: '49.99',
      currency: '',
      transactionId: '',
      gtmOnSuccess: () => {},
      gtmOnFailure: () => fail('gtmOnFailure should not be called')
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 49.99, undefined, undefined);
- name: Non-numeric Order Value falls back to legacy conversion
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: 'not-a-number',
      currency: 'EUR',
      transactionId: 'ORD-1',
      gtmOnSuccess: () => {},
      gtmOnFailure: () => fail('gtmOnFailure should not be called')
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 1);
- name: Non-numeric Conversion Value falls back to 1
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: 'abc',
      gtmOnSuccess: () => {},
      gtmOnFailure: () => fail('gtmOnFailure should not be called')
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 1);
- name: Zero Order Value with an id and the option absent records the plain conversion
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: '0',
      currency: 'EUR',
      transactionId: 'ORD-0'
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 1);
    assertApi('callInWindow').wasNotCalledWith('tapper.push', 0, 'EUR', 'ORD-0');
- name: Zero Order Value with an id and the option off records the plain conversion
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: '0',
      currency: 'EUR',
      transactionId: 'ORD-0',
      sendOrderIdWithZeroValue: false
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 1);
    assertApi('callInWindow').wasNotCalledWith('tapper.push', 0, 'EUR', 'ORD-0');
- name: Zero Order Value with an id and the option on records value 0 with the id
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: '0',
      currency: 'EUR',
      transactionId: 'ORD-0',
      sendOrderIdWithZeroValue: true
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 0, 'EUR', 'ORD-0');
    assertApi('callInWindow').wasNotCalledWith('tapper.push', 1);
- name: Order Value 0.00 with the option on and no currency records value 0 with the id
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: '0.00',
      currency: '',
      transactionId: 'ORD-0',
      sendOrderIdWithZeroValue: true
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 0, undefined, 'ORD-0');
- name: Numeric Order Value 0 with the option on keeps a T-prefixed id as a string
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: 0,
      currency: 'EUR',
      transactionId: 'T123456789',
      sendOrderIdWithZeroValue: true
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 0, 'EUR', 'T123456789');
- name: A numeric order id stays a string on the zero-value push
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: '0',
      currency: 'EUR',
      transactionId: 123456789,
      sendOrderIdWithZeroValue: true
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 0, 'EUR', '123456789');
    assertApi('callInWindow').wasNotCalledWith('tapper.push', 0, 'EUR', 123456789);
- name: Zero Order Value with the option on and an empty id records the plain conversion
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '3',
      orderValue: '0',
      currency: 'EUR',
      transactionId: '',
      sendOrderIdWithZeroValue: true
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 3);
    assertApi('callInWindow').wasNotCalledWith('tapper.push', 0, 'EUR', '');
- name: Zero Order Value with the option on and no id field records the plain conversion
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: '0',
      currency: 'EUR',
      sendOrderIdWithZeroValue: true
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 1);
- name: Blank Order Value with the option on records the plain conversion
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: ' ',
      currency: 'EUR',
      transactionId: 'ORD-0',
      sendOrderIdWithZeroValue: true
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 1);
    assertApi('callInWindow').wasNotCalledWith('tapper.push', 0, 'EUR', 'ORD-0');
- name: False Order Value with the option on records the plain conversion
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: false,
      currency: 'EUR',
      transactionId: 'ORD-0',
      sendOrderIdWithZeroValue: true
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 1);
    assertApi('callInWindow').wasNotCalledWith('tapper.push', 0, 'EUR', 'ORD-0');
- name: Positive Order Value with the option on is unchanged
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: '49.99',
      currency: 'EUR',
      transactionId: 'ORD-1',
      sendOrderIdWithZeroValue: true
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 49.99, 'EUR', 'ORD-1');
- name: Positive Order Value with the option off is unchanged
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: '49.99',
      currency: 'EUR',
      transactionId: 'ORD-1',
      sendOrderIdWithZeroValue: false
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 49.99, 'EUR', 'ORD-1');
- name: Negative Order Value with the option on records the plain conversion
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: '-10',
      currency: 'EUR',
      transactionId: 'ORD-1',
      sendOrderIdWithZeroValue: true
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 1);
    assertApi('callInWindow').wasNotCalledWith('tapper.push', 0, 'EUR', 'ORD-1');
- name: Non-numeric Order Value with the option on records the plain conversion
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: 'not-a-number',
      currency: 'EUR',
      transactionId: 'ORD-1',
      sendOrderIdWithZeroValue: true
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 1);
    assertApi('callInWindow').wasNotCalledWith('tapper.push', 0, 'EUR', 'ORD-1');
- name: Empty Order Value with the option on records the plain conversion
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: '',
      currency: 'EUR',
      transactionId: 'ORD-1',
      sendOrderIdWithZeroValue: true
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 1);
    assertApi('callInWindow').wasNotCalledWith('tapper.push', 0, 'EUR', 'ORD-1');
- name: Additional fields ride the value push as the fourth argument
  code: |-
    var pushArgs;
    mock('callInWindow', (path, a, b, c, d) => {
      if (path === 'tapper.push') pushArgs = [a, b, c, d];
    });
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: '49.99',
      currency: 'EUR',
      transactionId: 'ORD-1',
      additionalFields: [
        {name: 'partner_purchase', value: 'yes'},
        {name: 'voucher_applied', value: true}
      ],
      gtmOnSuccess: () => {},
      gtmOnFailure: () => fail('gtmOnFailure should not be called')
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertThat(pushArgs).isEqualTo([49.99, 'EUR', 'ORD-1', {partner_purchase: 'yes', voucher_applied: true}]);
- name: The object argument needs no sandbox permission of its own
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: '49.99',
      currency: 'EUR',
      transactionId: 'ORD-1',
      additionalFields: [{name: 'plan', value: 'annual'}],
      gtmOnSuccess: () => {},
      gtmOnFailure: () => fail('gtmOnFailure should not be called')
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalled();
- name: Additional fields ride the zero-value order push
  code: |-
    var pushArgs;
    mock('callInWindow', (path, a, b, c, d) => {
      if (path === 'tapper.push') pushArgs = [a, b, c, d];
    });
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: '0',
      currency: 'EUR',
      transactionId: 'ORD-0',
      sendOrderIdWithZeroValue: true,
      additionalFields: [{name: 'plan', value: 'annual'}],
      gtmOnSuccess: () => {},
      gtmOnFailure: () => fail('gtmOnFailure should not be called')
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertThat(pushArgs).isEqualTo([0, 'EUR', 'ORD-0', {plan: 'annual'}]);
- name: Additional fields ride the legacy conversion push after two undefined arguments
  code: |-
    var pushArgs;
    mock('callInWindow', (path, a, b, c, d) => {
      if (path === 'tapper.push') pushArgs = [a, b, c, d];
    });
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '3',
      orderValue: '',
      currency: 'EUR',
      transactionId: 'ORD-1',
      additionalFields: [{name: 'subscriber_status', value: 'new'}],
      gtmOnSuccess: () => {},
      gtmOnFailure: () => fail('gtmOnFailure should not be called')
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertThat(pushArgs[0]).isStrictlyEqualTo(3);
    assertThat(pushArgs[1]).isUndefined();
    assertThat(pushArgs[2]).isUndefined();
    assertThat(pushArgs[3]).isEqualTo({subscriber_status: 'new'});
- name: Field values keep the types the variables produced
  code: |-
    var pushArgs;
    mock('callInWindow', (path, a, b, c, d) => {
      if (path === 'tapper.push') pushArgs = [a, b, c, d];
    });
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: '49.99',
      currency: 'EUR',
      transactionId: 'ORD-1',
      additionalFields: [
        {name: 'plan', value: 'premium'},
        {name: 'seats', value: 4},
        {name: 'partner_purchase', value: false}
      ],
      gtmOnSuccess: () => {},
      gtmOnFailure: () => fail('gtmOnFailure should not be called')
    };
    runCode(mockData);
    assertThat(pushArgs[3].plan).isStrictlyEqualTo('premium');
    assertThat(pushArgs[3].seats).isStrictlyEqualTo(4);
    assertThat(pushArgs[3].partner_purchase).isFalse();
- name: A field name given as a number is kept as text
  code: |-
    var pushArgs;
    mock('callInWindow', (path, a, b, c, d) => {
      if (path === 'tapper.push') pushArgs = [a, b, c, d];
    });
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: '49.99',
      currency: 'EUR',
      transactionId: 'ORD-1',
      additionalFields: [{name: 2026, value: 'yes'}],
      gtmOnSuccess: () => {},
      gtmOnFailure: () => fail('gtmOnFailure should not be called')
    };
    runCode(mockData);
    assertThat(pushArgs[3]).isEqualTo({'2026': 'yes'});
- name: Rows with no name or no value are skipped and the rest are kept
  code: |-
    var pushArgs;
    mock('callInWindow', (path, a, b, c, d) => {
      if (path === 'tapper.push') pushArgs = [a, b, c, d];
    });
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: '49.99',
      currency: 'EUR',
      transactionId: 'ORD-1',
      additionalFields: [
        {name: '', value: 'dropped'},
        {name: 'voucher_applied', value: undefined},
        {name: 'partner_purchase', value: null},
        {name: 'plan', value: 'annual'}
      ],
      gtmOnSuccess: () => {},
      gtmOnFailure: () => fail('gtmOnFailure should not be called')
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertThat(pushArgs).isEqualTo([49.99, 'EUR', 'ORD-1', {plan: 'annual'}]);
- name: An empty additional fields table pushes exactly the three value arguments
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: '49.99',
      currency: 'EUR',
      transactionId: 'ORD-1',
      additionalFields: [],
      gtmOnSuccess: () => {},
      gtmOnFailure: () => fail('gtmOnFailure should not be called')
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 49.99, 'EUR', 'ORD-1');
- name: Rows that all get skipped push exactly what the tag pushed before the option
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: '',
      currency: '',
      transactionId: '',
      additionalFields: [{name: '', value: ''}, {name: 'plan', value: null}],
      gtmOnSuccess: () => {},
      gtmOnFailure: () => fail('gtmOnFailure should not be called')
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 1);
- name: An additional fields value that is not a table is ignored
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: '49.99',
      currency: 'EUR',
      transactionId: 'ORD-1',
      additionalFields: 'not-a-table',
      gtmOnSuccess: () => {},
      gtmOnFailure: () => fail('gtmOnFailure should not be called')
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 49.99, 'EUR', 'ORD-1');
- name: A tag saved before the option existed pushes exactly the three value arguments
  code: |-
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      orderValue: '49.99',
      currency: 'EUR',
      transactionId: 'ORD-1',
      gtmOnSuccess: () => {},
      gtmOnFailure: () => fail('gtmOnFailure should not be called')
    };
    runCode(mockData);
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 49.99, 'EUR', 'ORD-1');
setup: |-
  // The test sandbox loads no real script, so every scenario makes the bundle
  // load succeed; recordConversion() then runs after tapper.init. callInWindow
  // stays real, so the tapper.init and tapper.push grants are still checked.
  mock('injectScript', (url, onSuccess, onFailure, cacheToken) => {
    onSuccess();
  });


___NOTES___

Created on 29/05/2026
