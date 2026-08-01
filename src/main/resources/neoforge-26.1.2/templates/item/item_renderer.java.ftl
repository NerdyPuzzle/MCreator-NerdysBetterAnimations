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
		event.register(Identifier.parse("${modid}:${registryname}"), ${name}ItemRenderer.Unbaked.MAP_CODEC);
	}

	private static final Map<Integer, Function<Unbaked.CustomBakingContext, ${name}ItemRenderer>> MODELS = Map.ofEntries(
		<#list models as model>
			Map.entry(${model[0]}, context -> new ${name}ItemRenderer(
				new <#if model[0] == -1 && data.animations?has_content>AnimatedModel<#else>${model[1]}</#if>(context.bakingContext().entityModelSet().bakeLayer(${model[1]}.LAYER_LOCATION)),
				Identifier.parse("${model[2].format("%s:textures/item/%s")}.png"),
				context.display()
			))<#sep>,
		</#list>
	);

	private final EntityModel<LivingEntityRenderState> model;
	private final Identifier texture;
	private final ItemDisplayContext displayContext;

	private final LivingEntityRenderState renderState;
	private final long start;

	private ${name}ItemRenderer(EntityModel<LivingEntityRenderState> model, Identifier texture, ItemDisplayContext displayContext) {
		this.model = model;
		this.texture = texture;
		this.displayContext = displayContext;
		this.renderState = new LivingEntityRenderState();
		this.start = System.currentTimeMillis();
	}

	@Override public void submit(ItemStack itemstack, PoseStack poseStack, SubmitNodeCollector submitNodeCollector, int lightCoords, int overlayCoords, boolean glint, int outlineColor) {
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
		boolean isFirstPerson = displayContext == ItemDisplayContext.FIRST_PERSON_LEFT_HAND || displayContext == ItemDisplayContext.FIRST_PERSON_RIGHT_HAND;
		boolean isThirdPerson = displayContext == ItemDisplayContext.THIRD_PERSON_LEFT_HAND || displayContext == ItemDisplayContext.THIRD_PERSON_RIGHT_HAND;
		if (model instanceof AnimatedModel animatedModel/*@perspective*/)
			animatedModel.setupItemStackAnim(this, itemstack, renderState);
		else
		</#if>
		model.setupAnim(renderState);

		<#if data.hasCustomJAVAModel() && data.animations?has_content>
		ModelPart root = model.root();
		Minecraft mc = Minecraft.getInstance();
		AbstractClientPlayer player = mc.player;
		AvatarRenderer playerRenderer = (AvatarRenderer) mc.getEntityRenderDispatcher().getRenderer(player);
		PlayerModel playerModel = (PlayerModel) playerRenderer.getModel();
		Identifier skinTexture = player.getSkin().body().texturePath();
		if (!player.isInvisible()) {
			searchAndRenderArm(root, "left_arm", playerModel, skinTexture, submitNodeCollector, poseStack, lightCoords, true, isFirstPerson);
			searchAndRenderArm(root, "right_arm", playerModel, skinTexture, submitNodeCollector, poseStack, lightCoords, false, isFirstPerson);
		}
		</#if>

		submitNodeCollector.submitModel(this.model, renderState, poseStack, texture, lightCoords, overlayCoords, outlineColor, null);

		if (glint) {
			submitNodeCollector.submitModel(this.model, renderState, poseStack, RenderTypes.entityGlint(), lightCoords, overlayCoords, -1, null);
		}

		poseStack.popPose();
	}

    <#if data.hasCustomJAVAModel() && data.animations?has_content>
	private void searchAndRenderArm(ModelPart root, String armName, PlayerModel playerModel, Identifier skinTexture, SubmitNodeCollector collector, PoseStack poseStack, int packedLight, boolean left, boolean firstPerson) {
		List<ModelPart> parentChain = findParentChain(root, armName);
		if (parentChain != null) {
			ModelPart arm = parentChain.get(parentChain.size() - 1).getChild(armName);
			if (firstPerson) {
				poseStack.pushPose();
				for (ModelPart parent : parentChain) {
					parent.translateAndRotate(poseStack);
				}
				ModelPart playerArm = left ? playerModel.leftArm : playerModel.rightArm;
				playerArm.loadPose(arm.storePose());
				collector.submitModelPart(playerArm, poseStack, RenderTypes.entityTranslucent(skinTexture), packedLight, OverlayTexture.NO_OVERLAY, null);
				poseStack.popPose();
			}
			arm.visible = false;
		}
	}

	private List<ModelPart> findParentChain(ModelPart current, String targetName) {
		if (current.hasChild(targetName)) {
			List<ModelPart> chain = new ArrayList<>();
			chain.add(current);
			return chain;
		}
		for (ModelPart child : current.children.values()) {
			List<ModelPart> childChain = findParentChain(child, targetName);
			if (childChain != null) {
				childChain.add(0, current);
				return childChain;
			}
		}
		return null;
	}
	</#if>

	@Override public ItemStack extractArgument(ItemStack itemstack) {
		return itemstack;
	}

	@Override public void getExtents(Consumer<Vector3fc> output) {
		PoseStack posestack = new PoseStack();
		this.model.root().getExtentsForGui(posestack, output);
	}

	private static boolean isInventory(ItemDisplayContext type) {
		return type == ItemDisplayContext.GUI || type == ItemDisplayContext.FIXED;
	}

	public record Unbaked(int index, ItemDisplayContext display) implements SpecialModelRenderer.Unbaked<ItemStack> {
		public static final MapCodec<${name}ItemRenderer.Unbaked> MAP_CODEC = RecordCodecBuilder.mapCodec(instance -> instance.group(
				ExtraCodecs.NON_NEGATIVE_INT.optionalFieldOf("index").xmap(opt -> opt.orElse(-1), i -> i == -1 ? Optional.empty() : Optional.of(i)).forGetter(${name}ItemRenderer.Unbaked::index),
				ItemDisplayContext.CODEC.optionalFieldOf("display", ItemDisplayContext.NONE).forGetter(${name}ItemRenderer.Unbaked::display)
		).apply(instance, ${name}ItemRenderer.Unbaked::new));

		@Override
		public MapCodec<${name}ItemRenderer.Unbaked> type() {
			return MAP_CODEC;
		}

		@Override
		public SpecialModelRenderer<ItemStack> bake(BakingContext bakingContext) {
			return ${name}ItemRenderer.MODELS.get(index).apply(new CustomBakingContext(bakingContext, display));
		}

		public record CustomBakingContext(BakingContext bakingContext, ItemDisplayContext display) {}

	}

	<#if data.hasCustomJAVAModel() && data.animations?has_content>
	private final Map<ItemStack, Map<Integer, AnimationState>> CACHE = new WeakHashMap<>();

	private Map<Integer, AnimationState> getAnimationState(ItemStack stack) {
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
		Minecraft mc = Minecraft.getInstance();
		CompoundTag data = itemstack.getOrDefault(DataComponents.CUSTOM_DATA, CustomData.EMPTY).copyTag();
		int elapsedTicks = (int) (mc.level.getGameTime() - data.getLongOr("animTime", 0));
		switch (data.getIntOr("animState", 420)) {
			<#list data.animations as animation>
			case -${animation?index + 1}:
				getAnimationState(itemstack).get(${animation?index}).stop();
				break;
			</#list>
			<#list data.animations as animation>
			case ${animation?index}:
				AnimationState state = getAnimationState(itemstack).get(${animation?index});
				float maxDurationTicks = ${animation.animation}.lengthInSeconds() * 20f;
				if (elapsedTicks >= 0 && elapsedTicks < maxDurationTicks) {
					if (!state.isStarted()) {
						state.start(tickCount);
					}
				}
				break;
			</#list>
		}
	}
	</#if>

	private static final class AnimatedModel extends ${data.customModelName.split(":")[0]} {

		<#list data.animations as animation>
		private final KeyframeAnimation keyframeAnimation${animation?index};
		</#list>

		public AnimatedModel(ModelPart root) {
			super(root);
			<#list data.animations as animation>
			this.keyframeAnimation${animation?index} = safeBake(${animation.animation});
			</#list>
		}

		<#-- ideally we would not do this, but many users use animations that animate parts
			 that don't exist in their model and then complain the game is crashing -->
		private KeyframeAnimation safeBake(AnimationDefinition source) {
			try {
				return source.bake(root);
			} catch (IllegalArgumentException e) {
				return new AnimationDefinition(0, false, Map.of()).bake(root);
			}
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