// ABOUTME: Configuration for reasoning/thinking model support
// ABOUTME: Carries thinking settings through the request pipeline to provider implementations
package org.nlogo.extensions.llm.models

import upickle.default.{ReadWriter => RW, macroRW}

/**
 * Configuration for reasoning/thinking model support
 *
 * @param enabled Whether thinking mode is active
 * @param reasoningEffort Optional effort level: "low", "medium", or "high"
 * @param budgetTokens Optional token budget for thinking (provider-specific minimum applies)
 */
case class ThinkingConfig(
  enabled: Boolean,
  reasoningEffort: Option[String] = None,
  budgetTokens: Option[Int] = None
)

object ThinkingConfig {
  implicit val rw: RW[ThinkingConfig] = macroRW

  /** Thinking disabled (standard mode) */
  val disabled: ThinkingConfig = ThinkingConfig(enabled = false)

  /** Thinking enabled with optional effort level */
  def withEffort(effort: String): ThinkingConfig =
    ThinkingConfig(enabled = true, reasoningEffort = Some(effort))

  /** Thinking enabled with a specific token budget */
  def withBudget(tokens: Int): ThinkingConfig =
    ThinkingConfig(enabled = true, budgetTokens = Some(tokens))
}
