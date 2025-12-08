package net.nerdypuzzle.betteranimations;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import net.mcreator.plugin.JavaPlugin;
import net.mcreator.plugin.Plugin;
import net.mcreator.plugin.events.ModifyTemplateResultEvent;
import net.mcreator.plugin.events.ui.ModElementGUIEvent;
import net.mcreator.ui.component.SearchableComboBox;
import net.mcreator.ui.component.util.ComponentUtils;
import net.mcreator.ui.component.util.PanelUtils;
import net.mcreator.ui.help.HelpUtils;
import net.mcreator.ui.init.L10N;
import net.mcreator.ui.laf.renderer.ModelComboBoxRenderer;
import net.mcreator.ui.laf.themes.Theme;
import net.mcreator.ui.modgui.ItemGUI;
import net.mcreator.workspace.Workspace;
import net.mcreator.workspace.elements.ModElement;
import net.mcreator.workspace.misc.WorkspaceInfo;
import net.mcreator.workspace.resources.Model;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import javax.swing.*;
import java.awt.*;
import java.io.FileReader;
import java.io.Reader;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.WeakHashMap;
import java.util.stream.Collectors;

public class Launcher extends JavaPlugin {
	private static final Logger LOG = LogManager.getLogger("Better animations");
	private static final String METADATA_KEY = "betteranimations_models";
	private static final String PERSPECTIVE_METADATA_KEY = "betteranimations_perspectives";
	private final Map<ItemGUI, SearchableComboBox<Model>> loadedSelectors = Collections.synchronizedMap(new WeakHashMap<>());
	private final Map<ItemGUI, JComboBox<String>> perspectiveSelectors = Collections.synchronizedMap(new WeakHashMap<>());

	public Launcher(Plugin plugin) {
		super(plugin);

		addListener(ModElementGUIEvent.AfterLoading.class, event -> {
			if (event.getModElementGUI() instanceof ItemGUI gui) {
				try {
					Field renderTypeField = ItemGUI.class.getDeclaredField("renderType");
					renderTypeField.setAccessible(true);
					SearchableComboBox<Model> renderType = (SearchableComboBox<Model>) renderTypeField.get(gui);

					Container rentPanel = renderType.getParent();
					Container parentOfRent = rentPanel.getParent();
					parentOfRent.remove(rentPanel);

					JPanel rent = new JPanel(new GridLayout(-1, 2, 2, 2));
					rent.setOpaque(false);

					rent.add(HelpUtils.wrapWithHelpButton(gui.withEntry("item/model"), L10N.label("elementgui.item.item_model")));
					rent.add(renderType);

					Field guiTextureField = ItemGUI.class.getDeclaredField("guiTexture");
					guiTextureField.setAccessible(true);
					rent.add(HelpUtils.wrapWithHelpButton(gui.withEntry("item/gui_texture"), L10N.label("elementgui.common.item_gui_texture")));
					rent.add(PanelUtils.centerInPanel((Component) guiTextureField.get(gui)));

					JComponent label = HelpUtils.wrapWithHelpButton(gui.withEntry("item/display_settings"), L10N.label("elementgui.item.display_settings"));

					SearchableComboBox<Model> jsonModelSelector = new SearchableComboBox<>(Model.getModelsWithTextureMaps(gui.getMCreator().getWorkspace()).stream()
							.filter(el -> el.getType() == Model.Type.JSON)
							.collect(Collectors.toList()));
					ComponentUtils.deriveFont(jsonModelSelector, 16);
					jsonModelSelector.setPreferredSize(new Dimension(350, 42));
					jsonModelSelector.setRenderer(new ModelComboBoxRenderer());
					loadedSelectors.put(gui, jsonModelSelector);

					JComponent perspectiveLabel = HelpUtils.wrapWithHelpButton(gui.withEntry("item/animation_perspectives"),
							L10N.label("elementgui.item.animation_perspectives"));
					JComboBox<String> animationPerspectives = new JComboBox<>(new String[]{
							"All perspectives",
							"Only in first person",
							"Only in third person"
					});
					ComponentUtils.deriveFont(animationPerspectives, 16);
					animationPerspectives.setPreferredSize(new Dimension(350, 42));
					perspectiveSelectors.put(gui, animationPerspectives);

					Workspace workspace = gui.getMCreator().getWorkspace();
					String elementName = gui.getModElement().getName();

					Object metadataRaw = workspace.getMetadata(METADATA_KEY);
					if (metadataRaw instanceof Map) {
						try {
							@SuppressWarnings("unchecked")
							Map<String, String> modelMap = (Map<String, String>) metadataRaw;
							if (modelMap.containsKey(elementName)) {
								String savedModelName = modelMap.get(elementName);
								for (int i = 0; i < jsonModelSelector.getItemCount(); i++) {
									Model m = jsonModelSelector.getItemAt(i);
									if (m.getReadableName().equals(savedModelName)) {
										jsonModelSelector.setSelectedItem(m);
										break;
									}
								}
							}
						} catch (Exception ex) {
							LOG.error("Failed to load custom model metadata", ex);
						}
					}

					Object perspectiveMetadataRaw = workspace.getMetadata(PERSPECTIVE_METADATA_KEY);
					if (perspectiveMetadataRaw instanceof Map) {
						try {
							@SuppressWarnings("unchecked")
							Map<String, String> perspectiveMap = (Map<String, String>) perspectiveMetadataRaw;
							if (perspectiveMap.containsKey(elementName)) {
								String savedPerspective = perspectiveMap.get(elementName);
								animationPerspectives.setSelectedItem(savedPerspective);
							}
						} catch (Exception ex) {
							LOG.error("Failed to load perspective metadata", ex);
						}
					}

					Runnable updateLayout = () -> {
						rent.remove(label);
						rent.remove(jsonModelSelector);
						rent.remove(perspectiveLabel);
						rent.remove(animationPerspectives);

						Model model = renderType.getSelectedItem();
						if (model != null && model.getType() == Model.Type.JAVA) {
							rent.add(label, 2);
							rent.add(jsonModelSelector, 3);
							rent.add(perspectiveLabel, 4);
							rent.add(animationPerspectives, 5);
						}

						rent.revalidate();
						rent.repaint();
					};

					renderType.addActionListener(e -> updateLayout.run());
					updateLayout.run();

					rent.setBorder(BorderFactory.createTitledBorder(
							BorderFactory.createLineBorder(Theme.current().getForegroundColor(), 1),
							L10N.t("elementgui.item.item_3d_model"),
							0, 0, gui.getFont().deriveFont(12.0f),
							Theme.current().getForegroundColor()));

					parentOfRent.add(rent, BorderLayout.CENTER);
					parentOfRent.revalidate();
					parentOfRent.repaint();

				} catch (NoSuchFieldException | IllegalAccessException e) {
					e.printStackTrace();
					LOG.error("Failed to replace rent panel: " + e.getMessage());
				}
			}
		});

		addListener(ModElementGUIEvent.WhenSaving.class, event -> {
			if (event.getModElementGUI() instanceof ItemGUI gui) {
				Workspace workspace = gui.getMCreator().getWorkspace();
				String elementName = gui.getModElement().getName();
				boolean workspaceDirty = false;

				if (loadedSelectors.containsKey(gui)) {
					SearchableComboBox<Model> selector = loadedSelectors.get(gui);
					Model selectedModel = selector.getSelectedItem();

					Object metadataRaw = workspace.getMetadata(METADATA_KEY);
					Map<String, String> modelMap;
					if (metadataRaw instanceof Map) {
						modelMap = (Map<String, String>) metadataRaw;
					} else {
						modelMap = new LinkedHashMap<>();
					}

					if (selectedModel != null) {
						modelMap.put(elementName, selectedModel.getReadableName());
					} else {
						modelMap.remove(elementName);
					}

					workspace.putMetadata(METADATA_KEY, modelMap);
					workspaceDirty = true;
				}

				if (perspectiveSelectors.containsKey(gui)) {
					JComboBox<String> perspectiveSelector = perspectiveSelectors.get(gui);
					String selectedPerspective = (String) perspectiveSelector.getSelectedItem();

					Object perspectiveMetadataRaw = workspace.getMetadata(PERSPECTIVE_METADATA_KEY);
					Map<String, String> perspectiveMap;
					if (perspectiveMetadataRaw instanceof Map) {
						perspectiveMap = (Map<String, String>) perspectiveMetadataRaw;
					} else {
						perspectiveMap = new LinkedHashMap<>();
					}

					if (selectedPerspective != null) {
						perspectiveMap.put(elementName, selectedPerspective);
					} else {
						perspectiveMap.remove(elementName);
					}

					workspace.putMetadata(PERSPECTIVE_METADATA_KEY, perspectiveMap);
					workspaceDirty = true;
				}

				if (workspaceDirty) {
					try {
						Method markDirtyMethod = Workspace.class.getDeclaredMethod("markDirty");
						markDirtyMethod.setAccessible(true);
						markDirtyMethod.invoke(workspace);
					} catch (Exception e) {
						LOG.warn("Could not mark workspace as dirty via reflection", e);
					}
				}
			}
		});

		addListener(ModifyTemplateResultEvent.class, event -> {
			if (event.getTemplateName() != null && event.getTemplateName().equals("json/item.json.ftl")) {
				try {
					Workspace workspace = ((WorkspaceInfo) event.getDataModel().get("w")).getWorkspace();
					String itemName = (String) event.getDataModel().get("name");
					ModElement item = workspace.getModElementByName(itemName);

					Object metadataRaw = workspace.getMetadata(METADATA_KEY);
					if (metadataRaw instanceof Map) {
						@SuppressWarnings("unchecked")
						Map<String, String> metadata = (Map<String, String>) metadataRaw;
						if (metadata.containsKey(item.getName())) {
							String customModelName = metadata.get(item.getName());
							Model customModel = Model.getModelByParams(workspace, customModelName, Model.Type.JSON);

							if (customModel == null || customModel.getFile() == null) {
								LOG.warn("Better Animations: Could not find custom JSON model file for item: {}", customModelName);
								return;
							}

							try (Reader reader = new FileReader(customModel.getFile())) {
								Gson gson = new Gson();
								JsonObject customModelJson = gson.fromJson(reader, JsonObject.class);

								if (customModelJson != null && customModelJson.has("display") && customModelJson.get("display").isJsonObject()) {
									JsonObject displaySettings = customModelJson.getAsJsonObject("display");
									JsonObject itemJson = gson.fromJson(event.getTemplateOutput(), JsonObject.class);
									itemJson.add("display", displaySettings);
									event.setTemplateOutput(gson.toJson(itemJson));
								}
							} catch (Exception e) {
								LOG.error("Better Animations: Error processing custom JSON model for item: {}", itemName, e);
							}
						}
					}
				} catch (Exception e) {
					LOG.error("Better Animations: Unhandled error in ModifyTemplateResultEvent listener.", e);
				}
			}

			if (event.getTemplateName() != null && event.getTemplateName().equals("item/item_renderer.java.ftl")) {
				try {
					Workspace workspace = ((WorkspaceInfo) event.getDataModel().get("w")).getWorkspace();
					String itemName = (String) event.getDataModel().get("name");
					ModElement item = workspace.getModElementByName(itemName);

					Object metadataRaw = workspace.getMetadata(METADATA_KEY);
					if (metadataRaw instanceof Map) {
						@SuppressWarnings("unchecked")
						Map<String, String> metadata = (Map<String, String>) metadataRaw;
						if (metadata.containsKey(item.getName())) {
							Object perspectiveMetadataRaw = workspace.getMetadata(PERSPECTIVE_METADATA_KEY);
							if (perspectiveMetadataRaw instanceof Map) {
								@SuppressWarnings("unchecked")
								Map<String, String> perspectiveMap = (Map<String, String>) perspectiveMetadataRaw;
								if (perspectiveMap.containsKey(item.getName())) {
									String animationPerspective = perspectiveMap.get(item.getName());
									switch(animationPerspective) {
										case "All perspectives":
											event.setTemplateOutput(event.getTemplateOutput().replace("/*@perspective*/", ""));
											break;
										case "Only in first person":
											event.setTemplateOutput(event.getTemplateOutput().replace("/*@perspective*/", "if (!isFirstPerson) resetAnimations(model);"));
											break;
										case "Only in third person":
											event.setTemplateOutput(event.getTemplateOutput().replace("/*@perspective*/", "if (!isThirdPerson) resetAnimations(model);"));
											break;
									}
								}
							}
						}
					}
				} catch (Exception e) {
					LOG.error("Better Animations: Unhandled error in ModifyTemplateResultEvent listener.", e);
				}
			}
		});

		LOG.info("Better animations plugin was loaded");
	}
}