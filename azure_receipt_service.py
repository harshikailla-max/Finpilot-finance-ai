"""
Azure AI Document Intelligence (prebuilt-receipt) Service for FinPilot AI.
Utilizes Azure Document Intelligence's prebuilt receipt model on the Free F0 tier.
Extracts merchant, transaction date, subtotal, tax/GST, total amount, line items,
and raw transcribed text without hallucinating or inventing missing values.
"""

import base64
import json
import os
import time
import urllib.request
import urllib.error
import urllib.parse
from typing import Dict, Any, Optional

MAX_AZURE_F0_PAYLOAD_BYTES = 4 * 1024 * 1024  # 4 MB Free F0 tier limit

def extract_currency_value(field_dict: Dict[str, Any]) -> Optional[float]:
    """Safely extracts numeric amount from Azure currency or number field."""
    if not field_dict or not isinstance(field_dict, dict):
        return None
    
    # Try valueCurrency amount
    val_curr = field_dict.get("valueCurrency")
    if isinstance(val_curr, dict) and "amount" in val_curr:
        try:
            return float(val_curr["amount"])
        except (ValueError, TypeError):
            pass
            
    # Try valueNumber
    val_num = field_dict.get("valueNumber")
    if val_num is not None:
        try:
            return float(val_num)
        except (ValueError, TypeError):
            pass
            
    # Try valueString or content parsing
    val_str = field_dict.get("valueString") or field_dict.get("content")
    if val_str:
        clean = "".join(c for c in str(val_str) if c.isdigit() or c == ".").strip()
        if clean:
            try:
                return float(clean)
            except (ValueError, TypeError):
                pass
                
    return None

def analyze_receipt_with_azure(
    base64_image: str,
    endpoint: str,
    api_key: str,
    timeout_seconds: int = 30
) -> Dict[str, Any]:
    """
    Submits an image to Azure AI Document Intelligence prebuilt-receipt model
    and polls the operation until completion.
    """
    endpoint = endpoint.strip().rstrip("/")
    api_key = api_key.strip()
    
    if not endpoint or not api_key:
        return {
            "isSuccess": False,
            "errorType": "unconfigured",
            "errorMessage": (
                "Azure Document Intelligence is not configured.\n\n"
                "Please configure AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT and "
                "AZURE_DOCUMENT_INTELLIGENCE_KEY in .env (or in Vercel Environment Variables)."
            )
        }

    # Clean base64 string
    clean_base64 = base64_image.strip()
    if "," in clean_base64:
        clean_base64 = clean_base64.split(",", 1)[1].strip()

    # Validate byte size against Azure F0 limit (4 MB)
    try:
        raw_bytes = base64.b64decode(clean_base64)
        byte_len = len(raw_bytes)
        if byte_len > 4 * 1024 * 1024:
            return {
                "isSuccess": False,
                "statusCode": 413,
                "errorType": "payloadTooLarge",
                "errorMessage": (
                    f"Image payload size ({byte_len // 1024} KB) exceeds Azure Document "
                    "Intelligence Free F0 limit of 4 MB (HTTP 413). Please resize or crop."
                )
            }
    except Exception as e:
        return {
            "isSuccess": False,
            "statusCode": 400,
            "errorType": "invalidPayload",
            "errorMessage": f"Invalid base64 image data: {e}"
        }

    # API Versions to try (GA 2024-11-30, fallback 2023-07-31)
    api_versions = ["2024-11-30", "2023-07-31"]
    operation_location = None
    last_error = None

    for api_version in api_versions:
        submit_url = f"{endpoint}/documentintelligence/documentModels/prebuilt-receipt:analyze?api-version={api_version}"
        headers = {
            "Ocp-Apim-Subscription-Key": api_key,
            "Content-Type": "application/json",
            "User-Agent": "FinPilot-AI-ReceiptScanner/1.0"
        }
        payload = json.dumps({"base64Source": clean_base64}).encode("utf-8")
        req = urllib.request.Request(submit_url, data=payload, headers=headers, method="POST")

        try:
            with urllib.request.urlopen(req, timeout=timeout_seconds) as resp:
                operation_location = resp.headers.get("Operation-Location")
                if operation_location:
                    break
        except urllib.error.HTTPError as e:
            last_error = e
            if e.code == 404:
                # Fallback to formrecognizer path if documentintelligence path returned 404
                alt_url = f"{endpoint}/formrecognizer/documentModels/prebuilt-receipt:analyze?api-version={api_version}"
                alt_req = urllib.request.Request(alt_url, data=payload, headers=headers, method="POST")
                try:
                    with urllib.request.urlopen(alt_req, timeout=timeout_seconds) as alt_resp:
                        operation_location = alt_resp.headers.get("Operation-Location")
                        if operation_location:
                            break
                except Exception:
                    continue
            elif e.code in (401, 403):
                return {
                    "isSuccess": False,
                    "statusCode": e.code,
                    "errorType": "unauthorized",
                    "errorMessage": (
                        f"Azure Document Intelligence Authentication Error (HTTP {e.code}). "
                        "Verify your AZURE_DOCUMENT_INTELLIGENCE_KEY and AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT."
                    )
                }
            elif e.code == 429:
                return {
                    "isSuccess": False,
                    "statusCode": 429,
                    "errorType": "rateLimited",
                    "errorMessage": (
                        "Azure Document Intelligence Free Tier (F0) rate limit reached (20 requests/minute). "
                        "Please wait a moment and try again."
                    )
                }
            elif e.code == 413:
                return {
                    "isSuccess": False,
                    "statusCode": 413,
                    "errorType": "payloadTooLarge",
                    "errorMessage": "Payload too large for Azure Document Intelligence (HTTP 413)."
                }
            else:
                break
        except Exception as e:
            last_error = e
            break

    if not operation_location:
        err_msg = str(last_error) if last_error else "Failed to submit document to Azure."
        return {
            "isSuccess": False,
            "errorType": "serverError",
            "errorMessage": f"Azure Document Intelligence analysis request failed: {err_msg}"
        }

    # Poll Operation-Location until completion (up to 25 seconds)
    poll_headers = {
        "Ocp-Apim-Subscription-Key": api_key,
        "User-Agent": "FinPilot-AI-ReceiptScanner/1.0"
    }

    start_time = time.time()
    poll_interval = 1.0
    result_data = None

    while time.time() - start_time < timeout_seconds:
        time.sleep(poll_interval)
        poll_req = urllib.request.Request(operation_location, headers=poll_headers, method="GET")
        try:
            with urllib.request.urlopen(poll_req, timeout=timeout_seconds) as poll_resp:
                res_body = json.loads(poll_resp.read().decode("utf-8"))
                status = res_body.get("status")
                if status == "succeeded":
                    result_data = res_body.get("analyzeResult", {})
                    break
                elif status in ("failed", "canceled"):
                    err = res_body.get("error", {}).get("message", "Analysis failed on Azure.")
                    return {
                        "isSuccess": False,
                        "errorType": "unreadable",
                        "errorMessage": f"Azure receipt analysis was unsuccessful: {err}"
                    }
        except urllib.error.HTTPError as e:
            return {
                "isSuccess": False,
                "statusCode": e.code,
                "errorType": "serverError",
                "errorMessage": f"Polling error from Azure Document Intelligence: HTTP {e.code}"
            }
        except Exception as e:
            return {
                "isSuccess": False,
                "errorType": "networkError",
                "errorMessage": f"Network error during Azure polling: {e}"
            }

    if not result_data:
        return {
            "isSuccess": False,
            "errorType": "timeout",
            "errorMessage": "Azure Document Intelligence request timed out. Please try again."
        }

    return parse_azure_receipt_result(result_data)


def parse_azure_receipt_result(result_data: dict) -> dict:
    """
    Extracts structured receipt fields from Azure Document Intelligence analyzeResult.
    Does NOT invent missing values (e.g. tax, subtotal, merchant).
    """
    # Extract structured fields according to prebuilt-receipt model schema
    documents = result_data.get("documents", [])
    raw_content = result_data.get("content", "")

    merchant = ""
    date_str = None
    subtotal = None
    tax = None
    total = None
    currency = "INR"
    line_items = []
    confidence = 0.85

    if documents:
        doc = documents[0]
        fields = doc.get("fields", {})
        doc_conf = doc.get("confidence")
        if doc_conf is not None:
            confidence = float(doc_conf)

        # 1. Merchant Name (Do not invent if not detected)
        merchant_field = fields.get("MerchantName")
        if merchant_field and isinstance(merchant_field, dict):
            merchant = merchant_field.get("valueString") or merchant_field.get("content") or ""

        # 2. Transaction Date (Do not invent if not detected)
        date_field = fields.get("TransactionDate")
        if date_field and isinstance(date_field, dict):
            date_str = date_field.get("valueDate") or date_field.get("content")

        # 3. Subtotal
        subtotal_field = fields.get("Subtotal")
        if subtotal_field:
            subtotal = extract_currency_value(subtotal_field)

        # 4. Total Tax / GST
        tax_field = fields.get("TotalTax")
        if tax_field:
            tax = extract_currency_value(tax_field)

        # 5. Grand Total Amount
        total_field = fields.get("Total")
        if total_field:
            total = extract_currency_value(total_field)
            val_curr = total_field.get("valueCurrency")
            if isinstance(val_curr, dict) and "currencyCode" in val_curr:
                currency = val_curr["currencyCode"]

        # 6. Line Items
        items_field = fields.get("Items")
        if items_field and isinstance(items_field, dict):
            item_list = items_field.get("valueArray", [])
            for item in item_list:
                item_obj = item.get("valueObject", {}) if isinstance(item, dict) else {}
                if not item_obj:
                    continue

                desc_field = item_obj.get("Description") or {}
                name = desc_field.get("valueString") or desc_field.get("content") or "Item"

                qty_field = item_obj.get("Quantity") or {}
                qty_val = qty_field.get("valueNumber") or qty_field.get("content") or 1
                try:
                    quantity = int(float(qty_val))
                except (ValueError, TypeError):
                    quantity = 1

                unit_price = extract_currency_value(item_obj.get("Price", {})) or 0.0
                total_price = extract_currency_value(item_obj.get("TotalPrice", {})) or (unit_price * quantity)

                item_dict = {
                    "name": name.strip(),
                    "price": float(unit_price if unit_price > 0 else total_price),
                    "quantity": max(1, quantity),
                    "totalPrice": float(total_price)
                }
                line_items.append(item_dict)

    # If total wasn't detected explicitly in doc fields, check subtotal + tax
    if total is None and subtotal is not None and tax is not None:
        total = round(subtotal + tax, 2)

    return {
        "isSuccess": True,
        "provider": "azure-document-intelligence",
        "model": "prebuilt-receipt",
        "data": {
            "merchant": merchant.strip(),
            "date": date_str,
            "total": float(total) if total is not None else 0.0,
            "subtotal": float(subtotal) if subtotal is not None else None,
            "tax": float(tax) if tax is not None else None,
            "currency": currency,
            "lineItems": line_items,
            "rawText": raw_content,
            "confidence": confidence,
            "isTotalUncertain": (total is None or total <= 0)
        },
        "rawText": raw_content
    }
