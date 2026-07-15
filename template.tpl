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
const conversion = data.conversion !== undefined && data.conversion !== '' ? makeNumber(data.conversion) : 1;

// Order Value must be a positive finite number to record a value. Anything
// else falls back to the legacy conversion path — never drop the conversion.
const maxOrderValue = 9999999999;
const hasOrderValue = data.orderValue !== undefined && data.orderValue !== '';
const orderValue = hasOrderValue ? makeNumber(data.orderValue) : undefined;
const orderValueIsValid = hasOrderValue && orderValue > 0 && orderValue <= maxOrderValue;

if (!pk) {
  logToConsole('Tapper: public key (pk) is missing');
  data.gtmOnFailure();
  return;
}

if (hasOrderValue && !orderValueIsValid) {
  logToConsole('Tapper: Order Value is not a positive number, recording the conversion without a value');
}

function recordConversion() {
  if (orderValueIsValid) {
    callInWindow('tapper.push', orderValue, data.currency || undefined, data.transactionId || undefined);
  } else {
    callInWindow('tapper.push', conversion);
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
setup: ''


___NOTES___

Created on 29/05/2026
