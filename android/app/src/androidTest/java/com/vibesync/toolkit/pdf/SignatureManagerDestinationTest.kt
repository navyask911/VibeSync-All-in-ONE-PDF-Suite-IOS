package com.vibesync.toolkit.pdf

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import android.app.Application
import com.vibesync.toolkit.pdf.core.designsystem.VibeSyncPdfTheme
import com.vibesync.toolkit.pdf.core.security.SecurityVault
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SignatureManagerDestinationTest {
    @get:Rule
    val composeTestRule = createComposeRule()

    private lateinit var vault: SecurityVault

    @Before
    fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Application>()
        vault = SecurityVault(context)
        vault.clearSignatures()
    }

    @After
    fun tearDown() {
        vault.clearSignatures()
    }

    @Test
    fun emptyStateCreateActionOpensSignaturePad() {
        val context = ApplicationProvider.getApplicationContext<Application>()
        val drawTitle = context.getString(R.string.signature_draw_title)

        composeTestRule.setContent {
            VibeSyncPdfTheme {
                SignatureManagerDestination(
                    onNavigateBack = {},
                    onSelectSignature = { bitmap, _, _, _, _, _ ->
                        if (!bitmap.isRecycled) bitmap.recycle()
                    },
                    securityVault = vault
                )
            }
        }

        composeTestRule.onNodeWithTag("signature_manager_empty").assertIsDisplayed()
        composeTestRule.onNodeWithTag("signature_manager_create")
            .assertIsDisplayed()
            .performClick()
        composeTestRule.onNodeWithText(drawTitle).assertIsDisplayed()
    }
}
