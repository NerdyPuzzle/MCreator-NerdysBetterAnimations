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

<#assign models = []>
<#if data.hasCustomJAVAModel()>
	<#assign models += [[
		-1,
		data.customModelName.split(":")[0],
		data.texture
	]]>
</#if>
<#list data.getModels() as model>
	<#if model.hasCustomJAVAModel()>
		<#assign models += [[
			model?index,
			model.customModelName.split(":")[0],
			model.texture
		]]>
	</#if>
</#list>

<@javacompress>
@EventBusSubscriber(Dist.CLIENT) public class ${name}ItemRenderer implements SpecialModelRenderer<ItemStack> {

	@SubscribeEvent public static void registerItemRenderers(RegisterSpecialModelRendererEvent event) {
		event.register(ResourceLocation.parse("${modid}:${registryname}"), ${name}ItemRenderer.Unbaked.MAP_CODEC);
	}

	private static final Map<Integer, Function<EntityModelSet, ${name}ItemRenderer>> MODELS = Map.ofEntries(
		<#list models as model>
			Map.entry(${model[0]}, modelSet -> new ${name}ItemRenderer(
				new <#if model[0] == -1 && data.animations?has_content>AnimatedModel<#else>${model[1]}</#if>(modelSet.bakeLayer(${model[1]}.LAYER_LOCATION)),
				ResourceLocation.parse("${model[2].format("%s:textures/item/%s")}.png")
			))<#sep>,
		</#list>
	);

	private final EntityModel<LivingEntityRenderState> model;
	private final ResourceLocation texture;

	private final LivingEntityRenderState renderState;
	private final long start;

	private ${name}ItemRenderer(EntityModel<LivingEntityRenderState> model, ResourceLocation texture) {
		this.model = model;
		this.texture = texture;
		this.renderState = new LivingEntityRenderState();
		this.start = System.currentTimeMillis();
	}

	@Override public void render(ItemStack itemstack, ItemDisplayContext displayContext, PoseStack poseStack, MultiBufferSource bufferSource, int packedLight, int packedOverlay, boolean glint) {
		<#if data.hasCustomJAVAModel() && data.animations?has_content>
		updateRenderState(itemstack);
		</#if>

		poseStack.pushPose();
		poseStack.translate(0.5, displayContext == ItemDisplayContext.GUI ? 1.525 : displayContext == ItemDisplayContext.GROUND ? 2.0 : 1.5, 0.45);
		poseStack.scale(1, -1, displayContext == ItemDisplayContext.GUI ? -1 : 1);
		poseStack.mulPose(Axis.YP.rotationDegrees(displayContext == ItemDisplayContext.GUI ? 180f : 0));
		poseStack.scale(-1, 1, 1);
		renderState.ageInTicks = (System.currentTimeMillis() - start) / 50.0f;
		<#if data.hasCustomJAVAModel() && data.animations?has_content>
		if (model instanceof AnimatedModel animatedModel)
			animatedModel.setupItemStackAnim(this, itemstack, renderState);
		else
		    model.setupAnim(renderState);
		VertexConsumer vertexConsumer = ItemRenderer.getFoilBuffer(bufferSource, model.renderType(texture), false, glint);
		boolean isFirstPerson = displayContext == ItemDisplayContext.FIRST_PERSON_LEFT_HAND || displayContext == ItemDisplayContext.FIRST_PERSON_RIGHT_HAND;
		boolean isThirdPerson = displayContext == ItemDisplayContext.THIRD_PERSON_LEFT_HAND || displayContext == ItemDisplayContext.THIRD_PERSON_RIGHT_HAND;
		/*@perspective*/
		try {
		    if (isFirstPerson && Minecraft.getInstance().player != null && (model.root().getChild("left_arm") != null || model.root().getChild("right_arm") != null)) {
			    AbstractClientPlayer player = Minecraft.getInstance().player;
			    PlayerRenderer playerRenderer = (PlayerRenderer) Minecraft.getInstance().getEntityRenderDispatcher().getRenderer(player);
			    PlayerModel playerModel = playerRenderer.getModel();
			    ResourceLocation skinTexture = player.getSkin().texture();
			    ItemArms.renderPartWithArms(model, poseStack, vertexConsumer, bufferSource, packedLight, packedOverlay, playerModel, skinTexture, player.isInvisible());
		    } else {
			    ModelPart leftArm = model.root().getChild("left_arm");
                ModelPart rightArm = model.root().getChild("right_arm");
			    if (leftArm != null)
			        leftArm.skipDraw = true;
			    if (rightArm != null) {
			        rightArm.skipDraw = true;
			        rightArm.offsetScale(new Vector3f(-rightArm.xScale, -rightArm.yScale, -rightArm.zScale));
			    }
			    model.renderToBuffer(poseStack, vertexConsumer, packedLight, packedOverlay);
		    }
		} catch (Exception ignored) {}
		<#else>
		VertexConsumer vertexConsumer = ItemRenderer.getFoilBuffer(bufferSource, model.renderType(texture), false, glint);
		model.setupAnim(renderState);
		model.renderToBuffer(poseStack, vertexConsumer, packedLight, packedOverlay);
		</#if>
		poseStack.popPose();
	}

	@Override public ItemStack extractArgument(ItemStack itemstack) {
		return itemstack;
	}

	@Override public void getExtents(Set<Vector3f> extentsSet) {
		PoseStack posestack = new PoseStack();
		this.model.root().getExtentsForGui(posestack, extentsSet);
	}

	private static boolean isInventory(ItemDisplayContext type) {
		return type == ItemDisplayContext.GUI || type == ItemDisplayContext.FIXED;
	}

	public record Unbaked(int index) implements SpecialModelRenderer.Unbaked {
		public static final MapCodec<${name}ItemRenderer.Unbaked> MAP_CODEC = RecordCodecBuilder.mapCodec(instance -> instance.group(
			ExtraCodecs.NON_NEGATIVE_INT.optionalFieldOf("index").xmap(opt -> opt.orElse(-1), i -> i == -1 ? Optional.empty() : Optional.of(i)).forGetter(${name}ItemRenderer.Unbaked::index)
		).apply(instance, ${name}ItemRenderer.Unbaked::new));

		@Override
		public MapCodec<${name}ItemRenderer.Unbaked> type() {
			return MAP_CODEC;
		}

		@Override
		public SpecialModelRenderer<?> bake(EntityModelSet modelSet) {
			return ${name}ItemRenderer.MODELS.get(index).apply(modelSet);
		}
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
					float elapsedSeconds = getAnimationState(itemstack).get(${animation?index}).getTimeInMillis(tickCount) / 1000.0F;
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
        int oldAnim = data.getIntOr("oldAnimState", 0);
        int newAnim = data.getIntOr("animState", 0);
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
                CustomData.update(DataComponents.CUSTOM_DATA, itemstack, tag -> tag.putInt("oldAnimState", itemstack.getOrDefault(DataComponents.CUSTOM_DATA, CustomData.EMPTY).copyTag().getIntOr("animState", 0)));
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
        model.root().getAllParts().forEach(ModelPart::resetPose);
    }
	</#if>

	private static final class AnimatedModel extends ${data.customModelName.split(":")[0]} {

		<#list data.animations as animation>
		private final KeyframeAnimation keyframeAnimation${animation?index};
		</#list>

		public AnimatedModel(ModelPart root) {
			super(root);
			<#list data.animations as animation>
			this.keyframeAnimation${animation?index} = ${animation.animation}.bake(root);
			</#list>
		}

		public void setupItemStackAnim(${name}ItemRenderer renderer, ItemStack itemstack, LivingEntityRenderState state) {
			this.root().getAllParts().forEach(ModelPart::resetPose);
			<#list data.animations as animation>
			this.keyframeAnimation${animation?index}.apply(renderer.getAnimationState(itemstack).get(${animation?index}), state.ageInTicks, ${animation.speed}f);
			</#list>
			super.setupAnim(state);
		}

	}
	</#if>

}
</@javacompress>
<#-- @formatter:on -->