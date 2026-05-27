package com.example.spendify

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap

class SmsReceiver : BroadcastReceiver() {

    companion object {

        // Duplicate cache
        private val recentTransactions =
            ConcurrentHashMap<String, Long>()

        private const val DUPLICATE_WINDOW_MS =
            5 * 60 * 1000 // 5 minutes
    }

    override fun onReceive(context: Context?, intent: Intent?) {

        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            return
        }

        val pendingResult = goAsync()

        try {

            for (smsMessage in Telephony.Sms.Intents.getMessagesFromIntent(intent)) {

                val sender =
                    smsMessage.displayOriginatingAddress ?: "UNKNOWN"

                val messageBody =
                    normalizeMessage(
                        smsMessage.messageBody ?: ""
                    )

                val timestamp = smsMessage.timestampMillis

                Log.d("SMS_RECEIVED", "Sender: $sender")
                Log.d("SMS_RECEIVED", "Message: $messageBody")

                // =================================================
                // STEP 1: SENDER VALIDATION
                // =================================================

                val senderTrust =
                    isValidIndianFinancialSender(sender)

                // =================================================
                // STEP 2: FILTERS
                // =================================================

                if (isOTPMessage(messageBody)) {

                    Log.d("SMS_FILTER", "Rejected OTP")
                    continue
                }

                if (isBalanceMessage(messageBody)) {

                    Log.d("SMS_FILTER", "Rejected Balance Message")
                    continue
                }

                if (isPromotionalMessage(messageBody)) {

                    Log.d("SMS_FILTER", "Rejected Promotional")
                    continue
                }

                if (isFailedTransaction(messageBody)) {

                    Log.d("SMS_FILTER", "Rejected Failed Transaction")
                    continue
                }

                if (containsSuspiciousUrl(messageBody)) {

                    Log.d("SMS_FILTER", "Rejected Suspicious URL")
                    continue
                }

                // =================================================
                // STEP 3: TRANSACTION VALIDATION
                // =================================================

                if (!isTransactionSMS(messageBody)) {

                    Log.d("SMS_FILTER", "Rejected Not Transaction")
                    continue
                }

                // =================================================
                // STEP 4: EXTRACT DATA
                // =================================================

                val amount = extractAmount(messageBody)

                if (amount == "0") {

                    Log.d("SMS_FILTER", "Rejected Invalid Amount")
                    continue
                }

                val merchant =
                    extractMerchant(messageBody)

                val type =
                    extractTransactionType(messageBody)

                val paymentMode =
                    detectPaymentMode(messageBody)

                val bank =
                    detectBank(sender)

                // =================================================
                // STEP 5: CONFIDENCE ENGINE
                // =================================================

                val confidence = calculateConfidence(
                    sender = sender,
                    message = messageBody,
                    amount = amount,
                    merchant = merchant,
                    senderTrust = senderTrust
                )

                Log.d("SMS_CONFIDENCE", confidence.toString())

                if (confidence < 60) {

                    Log.d("SMS_FILTER", "Rejected Low Confidence")
                    continue
                }

                // =================================================
                // STEP 6: DUPLICATE DETECTION
                // =================================================

                val transactionHash =
                    generateTransactionHash(
                        amount,
                        merchant,
                        type
                    )

                if (isDuplicate(transactionHash, timestamp)) {

                    Log.d("SMS_FILTER", "Rejected Duplicate")
                    continue
                }

                // =================================================
                // STEP 7: TRANSACTION MAP
                // =================================================

                val transactionData = hashMapOf(

                    "amount" to amount,
                    "merchant" to merchant,
                    "type" to type,
                    "paymentMode" to paymentMode,
                    "bank" to bank,
                    "sender" to sender,
                    "confidence" to confidence,
                    "timestamp" to timestamp,
                    "message" to sanitizeMessage(messageBody)
                )

                Log.d("TRANSACTION", transactionData.toString())

                // =================================================
                // STEP 8: SEND TO FLUTTER
                // =================================================

                MainActivity.smsChannel?.invokeMethod(
                    "newTransaction",
                    transactionData
                )
            }

        } catch (e: Exception) {

            Log.e(
                "SMS_ERROR",
                "Error processing SMS",
                e
            )

        } finally {

            pendingResult.finish()
        }
    }

    // =========================================================
    // NORMALIZE MESSAGE
    // =========================================================

    private fun normalizeMessage(message: String): String {

        return message
            .replace("\n", " ")
            .replace(Regex("""\s+"""), " ")
            .trim()
    }

    // =========================================================
    // VALID FINANCIAL SENDERS
    // =========================================================

    private fun isValidIndianFinancialSender(
        sender: String
    ): Boolean {

        val validPatterns = listOf(

            // BANKS

            Regex("""^[A-Z]{2}-HDFCBK$"""),
            Regex("""^[A-Z]{2}-SBIINB$"""),
            Regex("""^[A-Z]{2}-ICICIB$"""),
            Regex("""^[A-Z]{2}-AXISBK$"""),
            Regex("""^[A-Z]{2}-KOTAKB$"""),
            Regex("""^[A-Z]{2}-PNBSMS$"""),
            Regex("""^[A-Z]{2}-CBSSBI$"""),

            // UPI APPS

            Regex("""^[A-Z]{2}-GPAYIN$"""),
            Regex("""^[A-Z]{2}-PHONEP$"""),
            Regex("""^[A-Z]{2}-PAYTMB$"""),
            Regex("""^[A-Z]{2}-AMAZON$"""),
            Regex("""^[A-Z]{2}-CREDIN$"""),
            Regex("""^[A-Z]{2}-MOBIKW$"""),

            // FALLBACK

            Regex(""".*HDFC.*"""),
            Regex(""".*SBI.*"""),
            Regex(""".*ICICI.*"""),
            Regex(""".*AXIS.*"""),
            Regex(""".*GPAY.*"""),
            Regex(""".*PHONEPE.*"""),
            Regex(""".*PAYTM.*""")
        )

        return validPatterns.any {
            it.matches(sender.uppercase())
        }
    }

    // =========================================================
    // OTP DETECTION
    // =========================================================

    private fun isOTPMessage(message: String): Boolean {

        val keywords = listOf(

            "otp",
            "one time password",
            "verification code",
            "do not share",
            "valid for"
        )

        return keywords.any {
            message.contains(it, true)
        }
    }

    // =========================================================
    // BALANCE MESSAGE
    // =========================================================

    private fun isBalanceMessage(message: String): Boolean {

        val keywords = listOf(

            "available balance",
            "avl bal",
            "mini statement",
            "current balance",
            "ledger balance"
        )

        return keywords.any {
            message.contains(it, true)
        }
    }

    // =========================================================
    // PROMOTIONAL MESSAGE
    // =========================================================

    private fun isPromotionalMessage(message: String): Boolean {

        val keywords = listOf(

            "cashback",
            "reward",
            "offer",
            "voucher",
            "scratch card",
            "coupon",
            "win",
            "promo"
        )

        return keywords.any {
            message.contains(it, true)
        }
    }

    // =========================================================
    // FAILED TRANSACTION
    // =========================================================

    private fun isFailedTransaction(message: String): Boolean {

        val keywords = listOf(

            "failed",
            "declined",
            "unsuccessful",
            "reversed",
            "blocked",
            "could not be processed"
        )

        return keywords.any {
            message.contains(it, true)
        }
    }

    // =========================================================
    // SUSPICIOUS URL DETECTION
    // =========================================================

    private fun containsSuspiciousUrl(message: String): Boolean {

        val keywords = listOf(

            "bit.ly",
            "tinyurl",
            "http://",
            "https://"
        )

        return keywords.any {
            message.contains(it, true)
        }
    }

    // =========================================================
    // TRANSACTION VALIDATION
    // =========================================================

    private fun isTransactionSMS(message: String): Boolean {

        val keywords = listOf(

            "debited",
            "credited",
            "spent",
            "received",
            "withdrawn",
            "purchase",
            "payment",
            "upi txn",
            "transferred",
            "paid",
            "sent"
        )

        return keywords.any {
            message.contains(it, true)
        }
    }

    // =========================================================
    // AMOUNT EXTRACTION
    // =========================================================

    private fun extractAmount(message: String): String {

        val regex = Regex(

            """(?:Rs\.?|INR|₹)\s?([\d,]+(?:\.\d{1,2})?)""",
            RegexOption.IGNORE_CASE
        )

        val match = regex.find(message)

        return match?.groupValues
            ?.get(1)
            ?.replace(",", "")
            ?: "0"
    }

    // =========================================================
    // MERCHANT EXTRACTION
    // =========================================================

    private fun extractMerchant(message: String): String {

        val patterns = listOf(

            Regex(
                """at\s([A-Za-z0-9\s&._*-]+)""",
                RegexOption.IGNORE_CASE
            ),

            Regex(
                """to\s([A-Za-z0-9\s&._*-]+)""",
                RegexOption.IGNORE_CASE
            ),

            Regex(
                """via\s([A-Za-z0-9\s&._*-]+)""",
                RegexOption.IGNORE_CASE
            ),

            Regex(
                """paid\sto\s([A-Za-z0-9\s&._*-]+)""",
                RegexOption.IGNORE_CASE
            )
        )

        for (pattern in patterns) {

            val match = pattern.find(message)

            if (match != null) {

                return cleanMerchant(
                    match.groupValues[1]
                )
            }
        }

        return "Unknown Merchant"
    }

    // =========================================================
    // CLEAN MERCHANT
    // =========================================================

    private fun cleanMerchant(merchant: String): String {

        return merchant
            .replace(
                Regex("""\bon\b.*""", RegexOption.IGNORE_CASE),
                ""
            )
            .replace(
                Regex("""\bAvl\b.*""", RegexOption.IGNORE_CASE),
                ""
            )
            .replace(
                Regex("""[^A-Za-z0-9\s&._*-]"""),
                ""
            )
            .trim()
    }

    // =========================================================
    // TRANSACTION TYPE
    // =========================================================

    private fun extractTransactionType(
        message: String
    ): String {

        return when {

            message.contains("debited", true) ||
            message.contains("spent", true) ||
            message.contains("withdrawn", true) ||
            message.contains("paid", true) ||
            message.contains("sent", true) -> "DEBIT"

            message.contains("credited", true) ||
            message.contains("received", true) -> "CREDIT"

            else -> "UNKNOWN"
        }
    }

    // =========================================================
    // PAYMENT MODE
    // =========================================================

    private fun detectPaymentMode(
        message: String
    ): String {

        return when {

            message.contains("upi", true) -> "UPI"

            message.contains("atm", true) -> "ATM"

            message.contains("imps", true) -> "IMPS"

            message.contains("neft", true) -> "NEFT"

            message.contains("rtgs", true) -> "RTGS"

            message.contains("card", true) -> "CARD"

            else -> "BANK"
        }
    }

    // =========================================================
    // DETECT BANK
    // =========================================================

    private fun detectBank(sender: String): String {

        return when {

            sender.contains("HDFC", true) -> "HDFC"

            sender.contains("SBI", true) -> "SBI"

            sender.contains("ICICI", true) -> "ICICI"

            sender.contains("AXIS", true) -> "AXIS"

            sender.contains("KOTAK", true) -> "KOTAK"

            sender.contains("GPAY", true) -> "GPAY"

            sender.contains("PHONEP", true) -> "PHONEPE"

            sender.contains("PAYTM", true) -> "PAYTM"

            else -> "UNKNOWN"
        }
    }

    // =========================================================
    // CONFIDENCE ENGINE
    // =========================================================

    private fun calculateConfidence(
        sender: String,
        message: String,
        amount: String,
        merchant: String,
        senderTrust: Boolean
    ): Int {

        var score = 0

        if (senderTrust) score += 40

        if (amount != "0") score += 20

        if (merchant != "Unknown Merchant") score += 15

        if (isTransactionSMS(message)) score += 15

        if (containsAccountReference(message)) score += 10

        if (containsSuspiciousUrl(message)) score -= 50

        return score
    }

    // =========================================================
    // ACCOUNT REFERENCE VALIDATION
    // =========================================================

    private fun containsAccountReference(
        message: String
    ): Boolean {

        val regex = Regex(

            """(XX\d{2,4}|A/c|Acct|account|ending)""",
            RegexOption.IGNORE_CASE
        )

        return regex.containsMatchIn(message)
    }

    // =========================================================
    // DUPLICATE HASH
    // =========================================================

    private fun generateTransactionHash(
        amount: String,
        merchant: String,
        type: String
    ): String {

        val raw =
            "$amount-$merchant-$type"

        val bytes =
            MessageDigest
                .getInstance("SHA-256")
                .digest(raw.toByteArray())

        return bytes.joinToString("") {
            "%02x".format(it)
        }
    }

    // =========================================================
    // DUPLICATE DETECTION
    // =========================================================

    private fun isDuplicate(
        hash: String,
        timestamp: Long
    ): Boolean {

        cleanupOldTransactions(timestamp)

        val existing =
            recentTransactions[hash]

        return if (
            existing != null &&
            timestamp - existing < DUPLICATE_WINDOW_MS
        ) {

            true

        } else {

            recentTransactions[hash] = timestamp
            false
        }
    }

    // =========================================================
    // CLEANUP CACHE
    // =========================================================

    private fun cleanupOldTransactions(
        currentTime: Long
    ) {

        val iterator =
            recentTransactions.entries.iterator()

        while (iterator.hasNext()) {

            val entry = iterator.next()

            if (
                currentTime - entry.value >
                DUPLICATE_WINDOW_MS
            ) {

                iterator.remove()
            }
        }
    }

    // =========================================================
    // SANITIZE MESSAGE
    // =========================================================

    private fun sanitizeMessage(
        message: String
    ): String {

        return message

            // Mask account numbers
            .replace(
                Regex("""\b\d{8,16}\b"""),
                "XXXXXXXX"
            )

            // Mask phone numbers
            .replace(
                Regex("""\b\d{10}\b"""),
                "XXXXXXXXXX"
            )
    }
}