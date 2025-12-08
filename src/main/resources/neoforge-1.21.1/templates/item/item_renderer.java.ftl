<#--
 # MCreator (https://mcreator.net/)
 # Copyright (C) 2012-2020, Pylo
 # Copyright (C) 2020-2025, Pylo, opensource contributors
 #
 # This program is free software: you can redistribute it and/or modify
 # it under the terms of the GNU General Public License as published by
 # the Free Software Foundation, either version 3 of the License, or
 # (at your option) any later version.
 #
 # This program is distributed in the hope that it will be useful,
 # but WITHOUT ANY WARRANTY; without even the implied warranty of
 # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 # GNU General Public License for more details.
 #
 # You should have received a copy of the GNU General Public License
 # along with this program.  If not, see <https://www.gnu.org/licenses/>.
 #
 # Additional permission for code generator templates (*.ftl files)
 #
 # As a special exception, you may create a larger work that contains part or
 # all of the MCreator code generator templates (*.ftl files) and distribute
 # that work under terms of your choice, so long as that work isn't itself a
 # template for code generation. Alternatively, if you modify or redistribute
 # the template itself, you may (at your option) remove this special exception,
 # which will cause the template and the resulting code generator output files
 # to be licensed under the GNU General Public License without this special
 # exception.
-->

<#-- @formatter:off -->
<#include "../procedures.java.ftl">

package ${package}.client.renderer.item;

<@javacompress>
@OnlyIn(Dist.CLIENT)
<#if data.hasCustomJAVAModel() && data.animations?has_content>
@EventBusSubscriber(Dist.CLIENT)
</#if>
public class ${name}ItemRenderer extends BlockEntityWithoutLevelRenderer {

	private final EntityModelSet entityModelSet;
	private final ItemStack transformSource;

	private final Map<Integer, EntityModel<?>> models = new HashMap<>();
	private final long start;

	public ${name}ItemRenderer(BlockEntityRenderDispatcher blockEntityRenderDispatcher, EntityModelSet entityModelSet) {
		super(blockEntityRenderDispatcher, entityModelSet);
		this.entityModelSet = entityModelSet;
		this.transformSource = new ItemStack(${JavaModName}Items.${REGISTRYNAME}.get());

		this.start = System.currentTimeMillis();

		<#if data.hasCustomJAVAModel()>
			<#if data.animations?has_content>
			this.models.put(0, new AnimatedModel(this.entityModelSet.bakeLayer(${data.customModelName.split(":")[0]}.LAYER_LOCATION)));
			<#else>
			this.models.put(0, new ${data.customModelName.split(":")[0]}(this.entityModelSet.bakeLayer(${data.customModelName.split(":")[0]}.LAYER_LOCATION)));
			</#if>
		</#if>
		<#list data.getModels() as model>
			<#if model.hasCustomJAVAModel()>
			this.models.put(${model?index + 1}, new ${model.customModelName.split(":")[0]}(this.entityModelSet.bakeLayer(${model.customModelName.split(":")[0]}.LAYER_LOCATION)));
			</#if>
		</#list>
	}

	@Override public void renderByItem(ItemStack itemstack, ItemDisplayContext displayContext, PoseStack poseStack, MultiBufferSource bufferSource, int packedLight, int packedOverlay) {
		<#if data.hasCustomJAVAModel() && data.animations?has_content>
		updateRenderState(itemstack);
		</#if>

		EntityModel<?> model = this.models.get(0);
		ResourceLocation texture = ResourceLocation.parse("${data.texture.format("%s:textures/item/%s")}.png");
		<#list data.getModels() as model>
			<#if model.hasCustomJAVAModel()>
			if (<#list model.stateMap.entrySet() as entry>
					ItemProperties.getProperty(itemstack, ResourceLocation.parse("${generator.map(entry.getKey().getPrefixedName(registryname + "_"), "itemproperties")}"))
						.call(itemstack, Minecraft.getInstance().level, Minecraft.getInstance().player, 0) >= ${entry.getValue()?is_boolean?then(entry.getValue()?then("1", "0"), entry.getValue())}
				<#sep> && </#list>) {
				model = models.get(${model?index + 1});
				texture = ResourceLocation.parse("${model.texture.format("%s:textures/item/%s")}.png");
			}
			</#if>
		</#list>
		if (model == null) return;

		poseStack.pushPose();
		poseStack.translate(0.5, displayContext == ItemDisplayContext.GUI ? 1.525 : displayContext == ItemDisplayContext.GROUND ? 2.0 : 1.5, 0.45);
		poseStack.scale(1, -1, displayContext == ItemDisplayContext.GUI ? -1 : 1);
		poseStack.mulPose(Axis.YP.rotationDegrees(displayContext == ItemDisplayContext.GUI ? 180f : 0));
		poseStack.scale(-1, 1, 1);
		<#if data.hasCustomJAVAModel() && data.animations?has_content>
		VertexConsumer vertexConsumer = ItemRenderer.getFoilBufferDirect(bufferSource, model.renderType(texture), false, itemstack.hasFoil());
		if (model instanceof AnimatedModel animatedModel)
			animatedModel.setupItemStackAnim(itemstack, (System.currentTimeMillis() - start) / 50.0f);
		else {
		    model.setupAnim(null, 0, 0, (System.currentTimeMillis() - start) / 50.0f, 0, 0);
		}
		boolean isFirstPerson = displayContext == ItemDisplayContext.FIRST_PERSON_LEFT_HAND || displayContext == ItemDisplayContext.FIRST_PERSON_RIGHT_HAND;
		boolean isThirdPerson = displayContext == ItemDisplayContext.THIRD_PERSON_LEFT_HAND || displayContext == ItemDisplayContext.THIRD_PERSON_RIGHT_HAND;
		/*@perspective*/
		if (model instanceof AnimatedModel animatedModel && isFirstPerson && Minecraft.getInstance().player != null && (animatedModel.animator.root().getChild("left_arm") != null || animatedModel.animator.root().getChild("right_arm") != null)) {
			AbstractClientPlayer player = Minecraft.getInstance().player;
			PlayerRenderer playerRenderer = (PlayerRenderer) Minecraft.getInstance().getEntityRenderDispatcher().getRenderer(player);
			PlayerModel<?> playerModel = playerRenderer.getModel();
			ResourceLocation skinTexture = player.getSkin().texture();
			ItemArms.renderPartWithArms(animatedModel.animator, poseStack, vertexConsumer, bufferSource, packedLight, packedOverlay, playerModel, skinTexture, player.isInvisible());
		} else {
			model.renderToBuffer(poseStack, vertexConsumer, packedLight, packedOverlay);
		}
		<#else>
		    VertexConsumer vertexConsumer = ItemRenderer.getFoilBufferDirect(bufferSource, model.renderType(texture), false, itemstack.hasFoil());
		    model.setupAnim(null, 0, 0, (System.currentTimeMillis() - start) / 50.0f, 0, 0);
		    model.renderToBuffer(poseStack, vertexConsumer, packedLight, packedOverlay);
		</#if>
		poseStack.popPose();
	}

	private static boolean isLeftHand(ItemDisplayContext type) {
		return type == ItemDisplayContext.FIRST_PERSON_LEFT_HAND || type == ItemDisplayContext.THIRD_PERSON_LEFT_HAND;
	}

	private static boolean isInventory(ItemDisplayContext type) {
		return type == ItemDisplayContext.GUI || type == ItemDisplayContext.FIXED;
	}

	<#if data.hasCustomJAVAModel() && data.animations?has_content>
	private static final Map<ItemStack, Map<Integer, AnimationState>> CACHE = new WeakHashMap<>();

	private static Map<Integer, AnimationState> getAnimationState(ItemStack stack) {
		return CACHE.computeIfAbsent(stack, s -> IntStream.range(0, ${data.animations?size}).boxed().collect(Collectors.toMap(i -> i, i -> new AnimationState(), (a, b) -> b)));
	}

	private void updateRenderState(ItemStack itemstack) {
		int tickCount = (int) (System.currentTimeMillis() - start) / 50;
	    <#if data.animations?size != 0>
	        updateAnimation(itemstack, tickCount);
	    </#if>
		<#list data.animations as animation>
			<#if hasProcedure(animation.condition)>
				getAnimationState(itemstack).get(${animation?index}).animateWhen(<@procedureCode animation.condition, {
					"itemstack": "itemstack",
					"x": "Minecraft.getInstance().player.getX()",
					"y": "Minecraft.getInstance().player.getY()",
					"z": "Minecraft.getInstance().player.getZ()",
					"entity": "Minecraft.getInstance().player",
					"world": "Minecraft.getInstance().level"
				}, false/>, tickCount);
			<#else>
				if (getAnimationState(itemstack).get(${animation?index}).isStarted()) {
					float elapsedSeconds = getAnimationState(itemstack).get(${animation?index}).getAccumulatedTime() / 1000.0F;
					if (elapsedSeconds >= ${animation.animation}.lengthInSeconds()) {
						if (!${animation.animation}.looping())
							getAnimationState(itemstack).get(${animation?index}).stop();
						else
							getAnimationState(itemstack).get(${animation?index}).start(tickCount);
					}
				}
			</#if>
		</#list>
	}

	<#if data.animations?size != 0>
    private void updateAnimation(ItemStack itemstack, int tickCount) {
        CompoundTag data = itemstack.getOrDefault(DataComponents.CUSTOM_DATA, CustomData.EMPTY).copyTag();
        int oldAnim = data.getInt("oldAnimState");
        int newAnim = data.getInt("animState");
        if (oldAnim != newAnim) {
            switch (newAnim) {
				<#list data.animations as animation>
				case -${animation?index + 1}:
					getAnimationState(itemstack).get(${animation?index}).stop();
					break;
				</#list>
                <#list data.animations as animation>
				case ${animation?index}:
					getAnimationState(itemstack).get(${animation?index}).start(tickCount);
					break;
				</#list>
            }
            CustomData.update(DataComponents.CUSTOM_DATA, itemstack, tag -> tag.putInt("oldAnimState", newAnim));
        }
    }

    private static boolean init = false;

    @SubscribeEvent
    public static void resetItems(ClientTickEvent.Pre event) {
        if (Minecraft.getInstance().player != null && !CACHE.isEmpty() && !init) {
            for (Map.Entry<ItemStack, Map<Integer, AnimationState>> entry : CACHE.entrySet()) {
                ItemStack itemstack = entry.getKey();
                CustomData.update(DataComponents.CUSTOM_DATA, itemstack, tag -> tag.putInt("oldAnimState", itemstack.getOrDefault(DataComponents.CUSTOM_DATA, CustomData.EMPTY).copyTag().getInt("animState")));
                for (int i = 0; i < ${data.animations?size}; i++) {
                    getAnimationState(itemstack).get(i).stop();
                }
                init = true;
            }
        }
    }

    @SubscribeEvent
    public static void logOut(ClientPlayerNetworkEvent.LoggingOut event) {
        init = false;
    }

    public void resetAnimations(EntityModel model) {
        if (model instanceof AnimatedModel animated)
            animated.animator.root().getAllParts().forEach(ModelPart::resetPose);
    }
	</#if>

	private final class AnimatedModel extends ${data.customModelName.split(":")[0]} {

		private final ModelPart root;

		public final BlockEntityHierarchicalModel animator = new BlockEntityHierarchicalModel();

		public AnimatedModel(ModelPart root) {
			super(root);
			this.root = root;
		}

		public void setupItemStackAnim(ItemStack itemstack, float ageInTicks) {
			animator.setupItemStackAnim(itemstack, ageInTicks);
			super.setupAnim(null, 0, 0, ageInTicks, 0, 0);
		}

		private class BlockEntityHierarchicalModel extends HierarchicalModel<Entity> {

			@Override public ModelPart root() {
				return root;
			}

			@Override public void setupAnim(Entity entity, float limbSwing, float limbSwingAmount, float ageInTicks, float netHeadYaw, float headPitch) {
			}

			public void setupItemStackAnim(ItemStack itemstack, float ageInTicks) {
				animator.root().getAllParts().forEach(ModelPart::resetPose);
				<#list data.animations as animation>
				animator.animate(getAnimationState(itemstack).get(${animation?index}), ${animation.animation}, ageInTicks, ${animation.speed}f);
				</#list>
			}

		}

	}
	</#if>

}
</@javacompress>
<#-- @formatter:on -->