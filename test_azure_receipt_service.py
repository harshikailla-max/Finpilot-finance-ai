import unittest
import base64
import json
from azure_receipt_service import (
    analyze_receipt_with_azure,
    extract_currency_value,
    parse_azure_receipt_result,
    MAX_AZURE_F0_PAYLOAD_BYTES
)

class TestAzureReceiptService(unittest.TestCase):

    def test_payload_exceeding_f0_limit_returns_413(self):
        # Create dummy payload exceeding 4 MB
        oversized_bytes = b"x" * (MAX_AZURE_F0_PAYLOAD_BYTES + 1024)
        b64 = base64.b64encode(oversized_bytes).decode("ascii")

        res = analyze_receipt_with_azure(
            base64_image=b64,
            endpoint="https://test.cognitiveservices.azure.com/",
            api_key="0123456789abcdef0123456789abcdef"
        )
        self.assertFalse(res["isSuccess"])
        self.assertEqual(res["statusCode"], 413)
        self.assertEqual(res["errorType"], "payloadTooLarge")
        self.assertIn("4 MB", res["errorMessage"])

    def test_missing_credentials_returns_error(self):
        res = analyze_receipt_with_azure(
            base64_image="data:image/jpeg;base64,dGVzdA==",
            endpoint="",
            api_key=""
        )
        self.assertFalse(res["isSuccess"])
        self.assertEqual(res["errorType"], "unconfigured")

    def test_extract_currency_value(self):
        # Dictionary format
        self.assertEqual(extract_currency_value({"valueCurrency": {"amount": 250.75}}), 250.75)
        # valueNumber format
        self.assertEqual(extract_currency_value({"valueNumber": 120.0}), 120.0)
        # Content string format
        self.assertEqual(extract_currency_value({"content": "₹1,450.50"}), 1450.50)
        # Empty/None
        self.assertIsNone(extract_currency_value({}))
        self.assertIsNone(extract_currency_value(None))

    def test_parse_azure_receipt_result(self):
        sample_doc = {
            "fields": {
                "MerchantName": {"valueString": "Blue Tokai Coffee Roasters"},
                "TransactionDate": {"valueDate": "2026-10-15"},
                "Subtotal": {"valueCurrency": {"amount": 420.00}},
                "TotalTax": {"valueCurrency": {"amount": 21.00}},
                "Total": {"valueCurrency": {"amount": 441.00, "currencyCode": "INR"}},
                "Items": {
                    "valueArray": [
                        {
                            "valueObject": {
                                "Description": {"valueString": "Cold Brew Bold"},
                                "Quantity": {"valueNumber": 2},
                                "Price": {"valueCurrency": {"amount": 160.00}},
                                "TotalPrice": {"valueCurrency": {"amount": 320.00}}
                            }
                        },
                        {
                            "valueObject": {
                                "Description": {"valueString": "Almond Croissant"},
                                "Quantity": {"valueNumber": 1},
                                "Price": {"valueCurrency": {"amount": 100.00}},
                                "TotalPrice": {"valueCurrency": {"amount": 100.00}}
                            }
                        }
                    ]
                }
            },
            "confidence": 0.96
        }

        mock_analyze_result = {
            "documents": [sample_doc],
            "content": "Blue Tokai Coffee Roasters\nCold Brew Bold 2x 320\nAlmond Croissant 1x 100\nSubtotal: 420\nTax: 21\nTotal: 441"
        }

        parsed = parse_azure_receipt_result(mock_analyze_result)
        self.assertTrue(parsed["isSuccess"])
        data = parsed["data"]

        self.assertEqual(data["merchant"], "Blue Tokai Coffee Roasters")
        self.assertEqual(data["date"], "2026-10-15")
        self.assertEqual(data["subtotal"], 420.0)
        self.assertEqual(data["tax"], 21.0)
        self.assertEqual(data["total"], 441.0)
        self.assertEqual(data["currency"], "INR")
        self.assertEqual(len(data["lineItems"]), 2)
        self.assertEqual(data["lineItems"][0]["name"], "Cold Brew Bold")
        self.assertEqual(data["lineItems"][0]["quantity"], 2)
        self.assertEqual(data["lineItems"][0]["price"], 160.0)
        self.assertEqual(data["lineItems"][0]["totalPrice"], 320.0)

    def test_missing_values_are_not_invented(self):
        # Receipt with only merchant and total, missing tax and line items
        minimal_doc = {
            "fields": {
                "MerchantName": {"valueString": "Local Corner Store"},
                "Total": {"valueNumber": 50.0}
            }
        }
        parsed = parse_azure_receipt_result({"documents": [minimal_doc]})
        self.assertTrue(parsed["isSuccess"])
        data = parsed["data"]

        self.assertEqual(data["merchant"], "Local Corner Store")
        self.assertEqual(data["total"], 50.0)
        self.assertIsNone(data["subtotal"])  # NOT invented
        self.assertIsNone(data["tax"])       # NOT invented
        self.assertEqual(len(data["lineItems"]), 0)

if __name__ == "__main__":
    unittest.main()
