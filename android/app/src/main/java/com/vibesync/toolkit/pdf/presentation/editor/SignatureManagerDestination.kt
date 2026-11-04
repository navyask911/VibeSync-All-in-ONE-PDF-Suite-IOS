package com.vibesync.toolkit.pdf.presentation.editor

import android.graphics.Bitmap
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.vibesync.toolkit.pdf.core.security.SecurityVault
import java.util.UUID

/**
 * Wires the standalone Dashboard signature-manager destination to the existing signature pad.
 *
 * The manager is keyed after a successful capture so its one-time vault load sees the new item.
 */
@Composable
fun SignatureManagerDestination(
    onNavigateBack: () -> Unit,
    onSelectSignature: (Bitmap, Float, Float, Float, Float, Float) -> Unit,
    modifier: Modifier = Modifier,
    securityVault: SecurityVault? = null
) {
    val context = LocalContext.current
    val vault = remember(context, securityVault) {
        securityVault ?: SecurityVault(context)
    }
    var showSignaturePad by remember { mutableStateOf(false) }
    var refreshVersion by remember { mutableIntStateOf(0) }

    key(refreshVersion) {
        SignatureManagerScreen(
            onNavigateBack = onNavigateBack,
            onSelectSignature = onSelectSignature,
            modifier = modifier,
            securityVault = vault,
            onCreateSignature = { showSignaturePad = true }
        )
    }

    if (showSignaturePad) {
        SignaturePadDialog(
            onDismissRequest = { showSignaturePad = false },
            onSignatureCaptured = { bitmap, _ ->
                try {
                    vault.saveDefaultSignature(bitmap)
                    val signatureId = "signature_" +
                        System.currentTimeMillis() + "_" +
                        UUID.randomUUID().toString().take(8)
                    vault.saveSignature(signatureId, bitmap)
                    refreshVersion++
                } catch (error: Exception) {
                    Toast.makeText(
                        context,
                        error.localizedMessage ?: "Unable to save signature",
                        Toast.LENGTH_LONG
                    ).show()
                } finally {
                    if (!bitmap.isRecycled) bitmap.recycle()
                    showSignaturePad = false
                }
            }
        )
    }
}
