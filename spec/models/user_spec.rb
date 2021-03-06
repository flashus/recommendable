require 'spec_helper'

class UserSpec < MiniTest::Spec
  # User and Bully are skeleton classes defined in the dummy application for
  # the sole purpose of running these tests. They're in spec/dummy/models/ but
  # really, there's nothing there of note.
  
  describe User do
    describe "that does not act_as_recommendable" do
      before :each do
        @user = Factory(:bully)
        @movie = Factory(:movie)
      end
      
      it "should not be able to rate, ignore, or stash an item, and trying should not be enough to get Redis keys" do
        proc { @user.like(@movie) }.must_raise    NoMethodError
        proc { @user.dislike(@movie) }.must_raise NoMethodError
        proc { @user.ignore(@movie) }.must_raise  NoMethodError
        proc { @user.stash(@movie) }.must_raise  NoMethodError
        
        @movie.liked_by.must_be_empty
        @movie.disliked_by.must_be_empty
        
        proc { @user.create_recommended_to_sets }.must_raise NoMethodError
      
        proc { @user.likes_set_for(Movie) }.must_raise NoMethodError
        proc { @user.dislikes_set_for(Movie) }.must_raise NoMethodError
        
        Recommendable.redis.smembers("Bully:#{@user.id}:likes:Movie").must_be_empty
        Recommendable.redis.smembers("Bully:#{@user.id}:dislikes:Movie").must_be_empty
        Recommendable.redis.smembers("Bully:#{@user.id}:similarities").must_be_empty
        Recommendable.redis.smembers("Bully:#{@user.id}:predictions:Movie").must_be_empty
      end
    end
    
    describe "that does act_as_recommendable" do
      before :each do
        @user = Factory(:user)
        @movie = Factory(:movie)
      end

      after :each do
        Recommendable.redis.flushdb
      end

      it "should be able to like a recommendable item" do
        @user.like(@movie).must_equal true
        @user.send(:create_recommended_to_sets)
        Recommendable.redis.smembers("User:#{@user.id}:likes:Movie").must_include @movie.id.to_s
        @user.send(:destroy_recommended_to_sets)
      end

      it "should not dislike an item after liking it" do
        @user.dislike(@movie)
        @user.like(@movie).must_equal true
        @user.dislikes?(@movie).must_equal false
        @user.likes?(@movie).must_equal true

        @user.send(:create_recommended_to_sets)
        Recommendable.redis.smembers("User:#{@user.id}:dislikes:Movie").wont_include @movie.id.to_s
        @user.send(:destroy_recommended_to_sets)
      end

      it "should not be ignoring an item after liking it" do
        @user.ignore(@movie)
        @user.like(@movie).must_equal true
        @user.ignored?(@movie).must_equal false
        @user.likes?(@movie).must_equal true
      end

      it "should not have an item stashed after liking it" do
        @user.stash(@movie)
        @user.like(@movie).must_equal true
        @user.stashed?(@movie).must_equal false
        @user.likes?(@movie).must_equal true
      end

      it "should be able to dislike a recommendable item" do
        @user.dislike(@movie).must_equal true
        @user.send(:create_recommended_to_sets)
        Recommendable.redis.smembers("User:#{@user.id}:dislikes:Movie").must_include @movie.id.to_s
        @user.send(:destroy_recommended_to_sets)
      end

      it "should not like an item after disliking it" do
        @user.like(@movie)
        @user.dislike(@movie).must_equal true
        @user.likes?(@movie).must_equal false
        @user.dislikes?(@movie).must_equal true

        @user.send(:create_recommended_to_sets)
        Recommendable.redis.smembers("User:#{@user.id}:dislikes:Movie").must_include @movie.id.to_s
        Recommendable.redis.smembers("User:#{@user.id}:likes:Movie").wont_include @movie.id.to_s
        @user.send(:destroy_recommended_to_sets)
      end

      it "should not be ignoring an item after disliking it" do
        @user.ignore(@movie)
        @user.dislike(@movie).must_equal true
        @user.ignored?(@movie).must_equal false
        @user.dislikes?(@movie).must_equal true
      end

      it "should not have an item stashed after disliking it" do
        @user.stash(@movie)
        @user.dislike(@movie).must_equal true
        @user.stashed?(@movie).must_equal false
        @user.dislikes?(@movie).must_equal true
      end

      it "should be able to ignore a recommendable item" do
        @user.ignore(@movie).must_equal true
      end

      it "should not like an item after ignoring it" do
        @user.like(@movie)
        @user.ignore(@movie).must_equal true
        @user.likes?(@movie).must_equal false
        @user.ignored?(@movie).must_equal true
      end

      it "should not dislike an item after ignoring it" do
        @user.dislike(@movie)
        @user.ignore(@movie).must_equal true
        @user.dislikes?(@movie).must_equal false
        @user.ignored?(@movie).must_equal true
      end

      it "should not have an item stashed after ignoring it" do
        @user.stash(@movie)
        @user.ignore(@movie).must_equal true
        @user.stashed?(@movie).must_equal false
        @user.ignored?(@movie).must_equal true
      end

      it "should be able to stash a recommendable item" do
        @user.stash(@movie).must_equal true
      end

      it "should not stash a liked item" do
        @user.like(@movie)
        @user.stash(@movie).must_be_nil
        @user.likes?(@movie).must_equal true
        @user.stashed?(@movie).must_equal false
      end

      it "should not stash a disliked item" do
        @user.dislike(@movie)
        @user.stash(@movie).must_be_nil
        @user.dislikes?(@movie).must_equal true
        @user.stashed?(@movie).must_equal false
      end

      it "should not have an item ignored after stashing it" do
        @user.ignore(@movie)
        @user.stash(@movie).must_equal true
        @user.ignored?(@movie).must_equal false
        @user.stashed?(@movie).must_equal true
      end
      
      it "should not be able to rate or ignore an item that is not recommendable. doing so should not be enough to create Redis keys" do
        @cakephp = Factory(:php_framework)
        
        proc { @user.like(@cakephp) }.must_raise    Recommendable::RecordNotRecommendableError
        proc { @user.dislike(@cakephp) }.must_raise Recommendable::RecordNotRecommendableError
        proc { @user.ignore(@cakephp) }.must_raise  Recommendable::RecordNotRecommendableError
        proc { @user.stash(@cakephp) }.must_raise  Recommendable::RecordNotRecommendableError
        
        proc { @cakephp.liked_by }.must_raise    NoMethodError
        proc { @cakephp.disliked_by }.must_raise NoMethodError
        
        @user.send(:create_recommended_to_sets)
      
        Recommendable.redis.smembers("User:#{@user.id}:likes:PhpFramework").must_be_empty
        Recommendable.redis.smembers("User:#{@user.id}:dislikes:PhpFramework").must_be_empty
        Recommendable.redis.smembers("User:#{@user.id}:similarities").must_be_empty
        Recommendable.redis.smembers("User:#{@user.id}:predictions:Movie").must_be_empty
        
        @user.send(:destroy_recommended_to_sets)
      end
      
      it "should not freak out when re-rating, re-ignoring, or re-stashing items" do
        @user.like(@movie)
        @user.like(@movie).must_be_nil
        
        @user.dislike(@movie)
        @user.dislike(@movie).must_be_nil
        
        @user.ignore(@movie)
        @user.ignore(@movie).must_be_nil

        @user.stash(@movie)
        @user.stash(@movie).must_be_nil
      end

      it "should be able to unrate, unignore or unstash items" do
        @user.like(@movie)
        @user.unlike(@movie).must_equal true

        @user.dislike(@movie)
        @user.undislike(@movie).must_equal true
        
        @user.ignore(@movie)
        @user.unignore(@movie).must_equal true

        @user.stash(@movie)
        @user.unstash(@movie).must_equal true
      end
    end
    
    describe "while getting recommendations" do
      before :each do
        @dave   = Factory(:user)
        @frank  = Factory(:user)
        @hal    = Factory(:user)
        @movie1 = Factory(:movie)
        @movie2 = Factory(:movie)
        @movie3 = Factory(:movie)
        @movie4 = Factory(:movie)
        @movie5 = Factory(:movie)
      end
      
      after :each do
        Recommendable.redis.del "User:#{@dave.id}:similarities"
        Recommendable.redis.del "User:#{@dave.id}:predictions:Movie"
        Recommendable.redis.del "User:#{@frank.id}:similarities"
        Recommendable.redis.del "User:#{@frank.id}:predictions:Movie"
      end
      
      it "should get populated sorted sets for similarities and recommendations" do
        @dave.like(@movie1)
        @frank.like(@movie1)
        @frank.like(@movie2)
        @dave.send :update_similarities
        @dave.send :update_recommendations
        
        @dave.similar_raters.must_include @frank
        @dave.recommendations_for(Movie).must_include @movie2
      end
      
      it "should order similar users by similarity" do
        @dave.like(@movie1)
        @dave.like(@movie2)
        @frank.like(@movie1)
        @frank.dislike(@movie2)
        @hal.like(@movie1)
        @hal.like(@movie2)
        
        # hal should be more similar to dave than frank
        @dave.send :update_similarities
        @dave.send :update_recommendations
        
        @dave.similar_raters.must_equal [@hal, @frank]
      end
      
      it "should correctly recommend an awesome movie or two. In the correct order, of course." do
        @dave.like(@movie1)
        @dave.like(@movie2)
        @frank.like(@movie1)
        @frank.like(@movie2)
        @frank.like(@movie4)
        @hal.like(@movie1)
        @hal.like(@movie3)
        
        @dave.send :update_similarities
        @dave.send :update_recommendations
        
        @dave.recommendations.must_equal [@movie4, @movie3]
      end

      it "should not recommend rated items" do
        @dave.like(@movie1)
        @dave.dislike(@movie2)
        @frank.like(@movie1)
        @frank.like(@movie2)
        @frank.like(@movie4)
        @hal.like(@movie1)
        @hal.like(@movie3)
        
        @dave.send :update_similarities
        @dave.send :update_recommendations
        
        @dave.recommendations.wont_include @movie1
        @dave.recommendations.wont_include @movie2
      end

      it "should not recommend ignored items" do
        @dave.like(@movie1)
        @dave.like(@movie2)
        @dave.ignore(@movie4)
        @frank.like(@movie1)
        @frank.like(@movie2)
        @frank.like(@movie4)
        @hal.like(@movie1)
        @hal.like(@movie3)
        
        @dave.send :update_similarities
        @dave.send :update_recommendations
        
        @dave.recommendations.wont_include @movie4
      end

      it "should not recommend stashed items" do
        @dave.like(@movie1)
        @dave.like(@movie2)
        @dave.stash(@movie4)
        @frank.like(@movie1)
        @frank.like(@movie2)
        @frank.like(@movie4)
        @hal.like(@movie1)
        @hal.like(@movie3)
        
        @dave.send :update_similarities
        @dave.send :update_recommendations
        
        @dave.recommendations.wont_include @movie4
      end
    end
  end
end
