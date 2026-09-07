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
  "description": "Records a conversion event via the Tapper monitoring script. Fire this tag on the order/approval CONFIRMATION page only. Never on a landing page.",
  "categories": ["CONVERSIONS", "ADVERTISING"],
  "containerContexts": [
    "WEB"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "LABEL",
    "name": "placementNote",
    "displayName": "Fire this on the order/approval CONFIRMATION page only. Never on a landing page. A trigger that matches an ad landing page records a conversion for every visitor who clicks your ad, which corrupts your conversion data and switches off the traffic rules Tapper runs for converted visitors."
  },
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
    "help": "The conversion value to record. Defaults to 1. A fixed number here fires on every view of whatever page your trigger matches, so keep the trigger on the order/approval confirmation page."
  },
  {
    "type": "TEXT",
    "name": "orderValue",
    "displayName": "Order Value",
    "simpleValueType": true,
    "help": "Map your order total variable, e.g. {{Ecommerce Value}}. Must be a number. Leave empty to record a plain conversion (legacy behaviour). A hardcoded amount here fires on every view of whatever page your trigger matches, so keep the trigger on the order/approval confirmation page."
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

if (!pk) {
  logToConsole('Tapper: public key (pk) is missing');
  data.gtmOnFailure();
  return;
}

if (!conversionIsValid) {
  logToConsole('Tapper: Conversion Value is not a number, recording the conversion as 1');
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

// Idempotent loader. bundle.js must be fetched and evaluated AT MOST ONCE per
// page. Two independent signals say a bundle is already here:
//
//   1. `window.tapper` -- either the loader snippet's pre-init array buffer or
//      a live Tapper instance. Whichever loader put it there owns the init()
//      call, so this tag must not inject its own copy on top.
//   2. `window.tapperObject` -- written by the bundle at module scope on every
//      non-duplicate evaluation (tracker packages/client/src/index.ts), so its
//      presence means a bundle has ALREADY RUN on this page.
//
// Signal 2 exists because of the Citi incident (2026-08): a page carrying the
// merchant's own monitoring tag plus a second injected copy of bundle.js used
// to lose everything already buffered, since the second evaluation replaced the
// pre-init buffer with the first bundle's live instance. The tracker load-once
// guard (tracker 15533cc5, PR #12) made a duplicate evaluation a no-op, and it
// is why the `tapperObject` branch below must NOT inject: a second copy could
// not restore a missing `window.tapper` anyway, so reporting failure is honest
// where a silent `tapper.push` into nothing is not.
//
// The `'tapper-monitor-script'` cache token is the third layer: it de-dupes
// repeat fires of GTM-injected scripts inside this container.
var tapperExists = copyFromWindow('tapper');
var bundleAlreadyEvaluated = copyFromWindow('tapperObject') !== undefined;

if (tapperExists) {
  recordConversion();
} else if (bundleAlreadyEvaluated) {
  logToConsole('Tapper: a bundle already ran on this page but window.tapper is gone, not injecting a second copy');
  data.gtmOnFailure();
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
                  {"type": 1, "string": "tapperObject"},
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
- name: Injects the bundle when the page has none
  code: |-
    mock('copyFromWindow', function () { return undefined; });
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      gtmOnSuccess: () => {},
      gtmOnFailure: () => {}
    };
    runCode(mockData);
    assertApi('injectScript').wasCalled();
- name: Does not inject a second bundle when window.tapper is already there
  code: |-
    // The merchant's own monitoring snippet left its pre-init array buffer on
    // the page. Its loader owns init(); this tag only records.
    mock('copyFromWindow', function (key) {
      if (key === 'tapper') return [];
      return undefined;
    });
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      gtmOnSuccess: () => {},
      gtmOnFailure: () => fail('gtmOnFailure should not be called')
    };
    runCode(mockData);
    assertApi('injectScript').wasNotCalled();
    assertApi('callInWindow').wasCalledWith('tapper.push', 1);
    assertApi('gtmOnSuccess').wasCalled();
- name: Does not inject a second bundle when one has already evaluated
  code: |-
    // tapperObject on window means a bundle ALREADY RAN. A second copy is a
    // no-op since tracker 15533cc5, so injecting could not fix a missing
    // window.tapper - fail loudly instead of pushing into nothing.
    mock('copyFromWindow', function (key) {
      if (key === 'tapperObject') return [];
      return undefined;
    });
    const mockData = {
      pk: 'pk_test_123456789',
      conversion: '1',
      gtmOnSuccess: () => fail('gtmOnSuccess should not be called'),
      gtmOnFailure: () => {}
    };
    runCode(mockData);
    assertApi('injectScript').wasNotCalled();
    assertApi('gtmOnFailure').wasCalled();
setup: ''


___NOTES___

Created on 29/05/2026
